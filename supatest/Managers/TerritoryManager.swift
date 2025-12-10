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

// MARK: - TerritoryError

/// 领地操作错误类型
enum TerritoryError: Error, LocalizedError {
    case notAuthenticated
    case invalidCoordinates
    case uploadFailed(String)
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录"
        case .invalidCoordinates:
            return "无效的坐标数据"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
        case .loadFailed(let message):
            return "加载失败: \(message)"
        }
    }
}

// MARK: - TerritoryManager

/// 领地管理器
/// 负责领地数据的上传和拉取操作
@MainActor
class TerritoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = TerritoryManager()

    // MARK: - Published Properties

    /// 所有领地列表
    @Published var territories: [Territory] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - Init

    private init() {}

    // MARK: - Helper Methods

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...]
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }
    }

    /// 将坐标数组转换为 WKT 格式
    /// ⚠️ WKT 格式：经度在前，纬度在后
    /// ⚠️ 多边形必须闭合（首尾相同）
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 字符串，如 "SRID=4326;POLYGON((121.4 31.2, 121.5 31.2, ...))"
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else { return "" }

        // 确保多边形闭合
        var closedCoords = coordinates
        if let first = coordinates.first, let last = coordinates.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                closedCoords.append(first)
            }
        }

        // 转换为 WKT 格式（经度在前，纬度在后）
        let pointStrings = closedCoords.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }

        return "SRID=4326;POLYGON((\(pointStrings.joined(separator: ", "))))"
    }

    /// 计算边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard !coordinates.isEmpty else { return nil }

        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max() else {
            return nil
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - Upload

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - coordinates: 坐标数组
    ///   - area: 面积（平方米）
    ///   - startTime: 开始圈地时间
    func uploadTerritory(
        coordinates: [CLLocationCoordinate2D],
        area: Double,
        startTime: Date
    ) async throws {
        // 1. 检查用户登录状态
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw TerritoryError.notAuthenticated
        }

        // 2. 验证坐标
        guard coordinates.count >= 3 else {
            throw TerritoryError.invalidCoordinates
        }

        // 3. 准备数据
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)

        guard let bbox = calculateBoundingBox(coordinates) else {
            throw TerritoryError.invalidCoordinates
        }

        // 4. 构建上传数据
        let uploadData = TerritoryUploadData(
            userId: userId.uuidString,
            path: pathJSON,
            polygon: wktPolygon,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area: area,
            pointCount: coordinates.count,
            startedAt: startTime.ISO8601Format(),
            isActive: true
        )

        print("📤 开始上传领地...")
        print("   用户ID: \(userId.uuidString)")
        print("   点数: \(coordinates.count)")
        print("   面积: \(area) m²")
        print("   WKT: \(wktPolygon.prefix(100))...")

        // 5. 上传到 Supabase
        do {
            try await supabase
                .from("territories")
                .insert(uploadData)
                .execute()

            print("✅ 领地上传成功")
        } catch {
            print("❌ 领地上传失败: \(error)")
            throw TerritoryError.uploadFailed(error.localizedDescription)
        }
    }

    // MARK: - Upload Data Model

    /// 上传数据模型（用于 Codable 编码）
    private struct TerritoryUploadData: Codable {
        let userId: String
        let path: [[String: Double]]
        let polygon: String
        let bboxMinLat: Double
        let bboxMaxLat: Double
        let bboxMinLon: Double
        let bboxMaxLon: Double
        let area: Double
        let pointCount: Int
        let startedAt: String
        let isActive: Bool

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case path
            case polygon
            case bboxMinLat = "bbox_min_lat"
            case bboxMaxLat = "bbox_max_lat"
            case bboxMinLon = "bbox_min_lon"
            case bboxMaxLon = "bbox_max_lon"
            case area
            case pointCount = "point_count"
            case startedAt = "started_at"
            case isActive = "is_active"
        }
    }

    // MARK: - Load

    /// 加载所有激活的领地
    /// - Returns: 领地数组
    func loadAllTerritories() async throws -> [Territory] {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase
                .from("territories")
                .select("id, user_id, path, area, point_count, is_active")
                .eq("is_active", value: true)
                .execute()

            let decoder = JSONDecoder()
            let territories = try decoder.decode([Territory].self, from: response.data)

            self.territories = territories
            isLoading = false

            print("✅ 加载了 \(territories.count) 个领地")
            return territories

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            print("❌ 加载领地失败: \(error)")
            throw TerritoryError.loadFailed(error.localizedDescription)
        }
    }
}
