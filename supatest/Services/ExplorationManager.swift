//
//  ExplorationManager.swift
//  supatest
//
//  EarthLord Game - Exploration Manager
//  管理探索模式的核心逻辑
//

import Foundation
import CoreLocation
import Combine
import Supabase

// MARK: - POI 数据模型

struct POI: Codable, Identifiable {
    let id: String
    let poiType: String
    let name: String?
    let latitude: Double
    let longitude: Double
    var hasBeenDiscovered: Bool?
    var hasLoot: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case poiType = "poi_type"
        case name
        case latitude
        case longitude
        case hasBeenDiscovered = "has_been_discovered"
        case hasLoot = "has_loot"
    }
}

// MARK: - 探索统计

struct ExplorationStats {
    var startTime: Date?
    var totalDistance: Double = 0
    var lastLocation: CLLocationCoordinate2D?
}

// MARK: - 探索结果

struct ExplorationResult {
    let sessionId: UUID
    let duration: TimeInterval
    let totalDistance: Double
    let poisDiscovered: Int
    let rewards: [String: Any]?
}

// MARK: - RPC 响应模型

private struct StartExplorationResponse: Decodable {
    let session_id: UUID
}

private struct EndExplorationResponse: Decodable {
    let success: Bool
    let duration_seconds: Int?
    let message: String?
}

private struct POIResponse: Decodable {
    let id: String
    let poi_type: String
    let name: String?
    let latitude: Double
    let longitude: Double
    let distance_meters: Double?
    let discovered_by: UUID?
}

// MARK: - ExplorationManager

@MainActor
class ExplorationManager: ObservableObject {
    // MARK: - 单例

    static let shared = ExplorationManager()

    private init() {}

    // MARK: - 发布属性

    /// 是否在探索中
    @Published var isExploring: Bool = false

    /// 当前会话ID
    @Published var currentSessionId: UUID?

    /// 附近POI缓存
    @Published var nearbyPOIs: [POI] = []

    /// 已发现的POI ID集合
    @Published var discoveredPOIIds: Set<String> = []

    /// 本次探索统计
    @Published var explorationStats: ExplorationStats = ExplorationStats()

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 常量

    private let searchRadius: Double = 1000 // 搜索半径（米）

    // MARK: - 开始探索

    /// 开始探索会话
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - location: 当前位置
    func startExploration(userId: UUID, location: CLLocationCoordinate2D) async throws {
        guard !isExploring else {
            print("⚠️ 已经在探索中")
            return
        }

        errorMessage = nil

        do {
            // 调用 RPC 创建探索会话
            let params: [String: AnyJSON] = [
                "p_user_id": try AnyJSON(userId.uuidString),
                "p_lat": try AnyJSON(location.latitude),
                "p_lon": try AnyJSON(location.longitude)
            ]
            let response: StartExplorationResponse = try await supabase.rpc(
                "start_exploration",
                params: params
            ).execute().value

            // 保存会话ID
            currentSessionId = response.session_id

            // 初始化探索统计
            explorationStats = ExplorationStats(
                startTime: Date(),
                totalDistance: 0,
                lastLocation: location
            )

            // 获取附近POI
            await updatePOICache(location: location)

            // 加载已发现的POI列表
            await loadDiscoveredPOIIds(userId: userId)

            // 设置探索状态
            isExploring = true

            print("✅ 开始探索，会话ID: \(response.session_id)")

        } catch {
            errorMessage = "开始探索失败: \(error.localizedDescription)"
            print("❌ 开始探索失败: \(error)")
            throw error
        }
    }

    // MARK: - 结束探索

    /// 结束探索会话
    /// - Parameter location: 结束位置
    /// - Returns: 探索结果
    func stopExploration(location: CLLocationCoordinate2D) async throws -> ExplorationResult {
        guard isExploring, let sessionId = currentSessionId else {
            throw ExplorationError.notExploring
        }

        errorMessage = nil

        do {
            // 计算探索时长
            let duration = explorationStats.startTime.map { Date().timeIntervalSince($0) } ?? 0

            // 调用 RPC 结束探索会话
            let params: [String: AnyJSON] = [
                "p_session_id": try AnyJSON(sessionId.uuidString),
                "p_end_lat": try AnyJSON(location.latitude),
                "p_end_lon": try AnyJSON(location.longitude)
            ]
            let response: EndExplorationResponse = try await supabase.rpc(
                "end_exploration",
                params: params
            ).execute().value

            // 创建探索结果
            let result = ExplorationResult(
                sessionId: sessionId,
                duration: duration,
                totalDistance: explorationStats.totalDistance,
                poisDiscovered: discoveredPOIIds.count,
                rewards: nil // TODO: 后续实现奖励计算
            )

            // 重置状态
            isExploring = false
            currentSessionId = nil
            explorationStats = ExplorationStats()

            print("✅ 结束探索，时长: \(Int(duration))秒，距离: \(Int(explorationStats.totalDistance))米")

            return result

        } catch {
            errorMessage = "结束探索失败: \(error.localizedDescription)"
            print("❌ 结束探索失败: \(error)")
            throw error
        }
    }

    // MARK: - 更新POI缓存

    /// 更新附近POI缓存
    /// - Parameter location: 当前位置
    func updatePOICache(location: CLLocationCoordinate2D) async {
        do {
            let params: [String: AnyJSON] = [
                "p_lat": try AnyJSON(location.latitude),
                "p_lon": try AnyJSON(location.longitude),
                "p_radius_meters": try AnyJSON(searchRadius)
            ]
            let response: [POIResponse] = try await supabase.rpc(
                "get_pois_within_radius",
                params: params
            ).execute().value

            // 转换为 POI 模型
            nearbyPOIs = response.map { poi in
                POI(
                    id: poi.id,
                    poiType: poi.poi_type,
                    name: poi.name,
                    latitude: poi.latitude,
                    longitude: poi.longitude,
                    hasBeenDiscovered: poi.discovered_by != nil,
                    hasLoot: nil
                )
            }

            print("📍 更新POI缓存，共 \(nearbyPOIs.count) 个")

        } catch {
            print("❌ 更新POI缓存失败: \(error)")
        }
    }

    // MARK: - 加载已发现POI

    /// 加载用户已发现的POI ID列表
    /// - Parameter userId: 用户ID
    func loadDiscoveredPOIIds(userId: UUID) async {
        do {
            let response: [String] = try await supabase.rpc(
                "get_player_discovered_poi_ids",
                params: [
                    "p_user_id": userId.uuidString
                ]
            ).execute().value

            discoveredPOIIds = Set(response)

            print("📋 已发现POI数量: \(discoveredPOIIds.count)")

        } catch {
            print("❌ 加载已发现POI失败: \(error)")
        }
    }

    // MARK: - 更新位置

    /// 更新用户位置（计算移动距离）
    /// - Parameter newLocation: 新位置
    func updateLocation(_ newLocation: CLLocationCoordinate2D) {
        guard isExploring else { return }

        if let lastLocation = explorationStats.lastLocation {
            // 计算距离
            let distance = calculateDistance(from: lastLocation, to: newLocation)
            explorationStats.totalDistance += distance
        }

        explorationStats.lastLocation = newLocation
    }

    // MARK: - 辅助方法

    /// 计算两点之间的距离（米）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// 检查POI是否已被发现
    func isPOIDiscovered(_ poiId: String) -> Bool {
        return discoveredPOIIds.contains(poiId)
    }
}

// MARK: - 探索错误

enum ExplorationError: LocalizedError {
    case notExploring
    case alreadyExploring
    case invalidSession
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notExploring:
            return "当前没有进行中的探索"
        case .alreadyExploring:
            return "已经在探索中"
        case .invalidSession:
            return "无效的探索会话"
        case .networkError(let message):
            return "网络错误: \(message)"
        }
    }
}
