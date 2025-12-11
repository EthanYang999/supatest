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

    // MARK: - Day 19: 碰撞检测算法

    /// 射线法判断点是否在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return .safe }

        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd = path[i + 1]

            for territory in otherTerritories {
                let polygon = territory.toCoordinates()
                guard polygon.count >= 3 else { continue }

                // 检查与领地每条边的相交
                for j in 0..<polygon.count {
                    let boundaryStart = polygon[j]
                    let boundaryEnd = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                        TerritoryLogger.shared.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pathCrossTerritory,
                            message: "轨迹不能穿越他人领地！",
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }

                // 检查路径点是否在领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    TerritoryLogger.shared.log("路径碰撞：轨迹点进入他人领地", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pointInTerritory,
                        message: "轨迹不能进入他人领地！",
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到他人领地的最近距离
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
        let otherTerritories = territories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return Double.infinity }

        var minDistance = Double.infinity
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()

            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)
                minDistance = min(minDistance, distance)
            }
        }

        return minDistance
    }

    /// 综合碰撞检测（主方法）
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 检查路径是否穿越他人领地
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision {
            return crossResult
        }

        // 2. 计算到最近领地的距离
        guard let lastPoint = path.last else { return .safe }
        let minDistance = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        // 3. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = "注意：距离他人领地 \(Int(minDistance))m"
        } else if minDistance > 25 {
            warningLevel = .warning
            message = "警告：正在靠近他人领地（\(Int(minDistance))m）"
        } else {
            warningLevel = .danger
            message = "危险：即将进入他人领地！（\(Int(minDistance))m）"
        }

        if warningLevel != .safe {
            TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离 \(Int(minDistance))m", type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDistance,
            warningLevel: warningLevel
        )
    }
}
