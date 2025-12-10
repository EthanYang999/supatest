//
//  TerritoryManager.swift
//  supatest
//
//  EarthLord Game - 领地管理器
//  负责领地数据的上传和拉取
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - TerritoryManager

/// 领地管理器
/// 负责领地数据的上传到 Supabase 和从 Supabase 拉取
@MainActor
final class TerritoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TerritoryManager()

    // MARK: - Published Properties

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var territories: [Territory] = []

    // MARK: - Initialization

    private init() {}

    // MARK: - 坐标转换方法

    /// 将坐标数组转换为 path JSON 格式
    /// 格式：[{"lat": x, "lon": y}, ...]
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转换为 WKT 格式
    /// 注意：WKT 格式是「经度在前，纬度在后」
    /// 多边形必须闭合（首尾相同）
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else {
            return "SRID=4326;POLYGON EMPTY"
        }

        // 确保闭合：如果首尾不同，添加起点作为终点
        var closedCoords = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                closedCoords.append(first)
            }
        }

        // WKT 格式：经度在前，纬度在后
        let pointStrings = closedCoords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }

        let polygonString = pointStrings.joined(separator: ", ")
        return "SRID=4326;POLYGON((\(polygonString)))"
    }

    /// 计算坐标数组的边界框
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传领地

    /// 上传领地到 Supabase
    func uploadTerritory(
        coordinates: [CLLocationCoordinate2D],
        area: Double,
        startTime: Date
    ) async throws {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        // 1. 获取当前用户ID
        guard let userId = try? await supabase.auth.session.user.id else {
            let error = "未登录，无法上传领地"
            errorMessage = error
            TerritoryLogger.shared.log(error, type: .error)
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
        }

        // 2. 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)
        let bbox = calculateBoundingBox(coordinates)

        // 3. 构建上传数据
        let uploadData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "path": .array(pathJSON.map { dict in
                .object(dict.mapValues { .double($0) })
            }),
            "polygon": .string(wktPolygon),
            "bbox_min_lat": .double(bbox.minLat),
            "bbox_max_lat": .double(bbox.maxLat),
            "bbox_min_lon": .double(bbox.minLon),
            "bbox_max_lon": .double(bbox.maxLon),
            "area": .double(area),
            "point_count": .integer(coordinates.count),
            "started_at": .string(startTime.ISO8601Format()),
            "is_active": .bool(true)
        ]

        TerritoryLogger.shared.log("准备上传领地: \(coordinates.count)个点, 面积\(Int(area))m²", type: .info)

        // 4. 上传到 Supabase
        do {
            try await supabase
                .from("territories")
                .insert(uploadData)
                .execute()

            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
            print("✅ 领地上传成功")

        } catch {
            let errorMsg = "领地上传失败: \(error.localizedDescription)"
            errorMessage = errorMsg
            TerritoryLogger.shared.log(errorMsg, type: .error)
            print("❌ \(errorMsg)")
            throw error
        }
    }

    // MARK: - 拉取领地

    /// 从 Supabase 加载所有激活的领地
    func loadAllTerritories() async throws -> [Territory] {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        TerritoryLogger.shared.log("开始拉取领地数据...", type: .info)

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("is_active", value: true)
                .execute()
                .value

            territories = response
            TerritoryLogger.shared.log("拉取成功: \(response.count)个领地", type: .success)
            print("✅ 拉取领地成功: \(response.count)个")

            return response

        } catch {
            let errorMsg = "拉取领地失败: \(error.localizedDescription)"
            errorMessage = errorMsg
            TerritoryLogger.shared.log(errorMsg, type: .error)
            print("❌ \(errorMsg)")
            throw error
        }
    }

    /// 加载当前用户的领地
    func loadMyTerritories() async throws -> [Territory] {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            let error = "未登录，无法加载领地"
            errorMessage = error
            TerritoryLogger.shared.log(error, type: .error)
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
        }

        TerritoryLogger.shared.log("开始拉取我的领地...", type: .info)

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            territories = response
            TerritoryLogger.shared.log("拉取成功: \(response.count)个我的领地", type: .success)
            print("✅ 拉取我的领地成功: \(response.count)个")

            return response

        } catch {
            let errorMsg = "拉取我的领地失败: \(error.localizedDescription)"
            errorMessage = errorMsg
            TerritoryLogger.shared.log(errorMsg, type: .error)
            print("❌ \(errorMsg)")
            throw error
        }
    }

    // MARK: - Day 18-B3b: 删除领地

    /// 删除领地
    func deleteTerritory(territoryId: String) async -> Bool {
        TerritoryLogger.shared.log("开始删除领地: \(territoryId)", type: .info)

        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId)
                .execute()

            // 从本地列表移除
            territories.removeAll { $0.id == territoryId }

            TerritoryLogger.shared.log("领地删除成功", type: .success)
            print("✅ 领地删除成功")
            return true

        } catch {
            let errorMsg = "删除领地失败: \(error.localizedDescription)"
            errorMessage = errorMsg
            TerritoryLogger.shared.log(errorMsg, type: .error)
            print("❌ \(errorMsg)")
            return false
        }
    }

    // MARK: - 辅助方法

    func clearError() {
        errorMessage = nil
    }
}
