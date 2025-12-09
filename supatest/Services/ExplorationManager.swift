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
    let rewards: [RewardItem]
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

    // MARK: - 依赖

    /// 发现管理器
    private let discoveryManager = DiscoveryManager.shared

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

    /// 本次探索发现的 POI 数量
    @Published var poisDiscoveredThisSession: Int = 0

    // MARK: - 私有属性

    /// 位置追踪定时器
    private var locationTrackingTimer: Timer?

    /// 当前用户 ID（探索期间保存）
    private var currentUserId: UUID?

    /// 上次触发 POI 检测的位置
    private var lastDetectionLocation: CLLocationCoordinate2D?

    // MARK: - 常量

    private let searchRadius: Double = 1000 // 搜索半径（米）
    private let trackingInterval: TimeInterval = 5 // 位置追踪间隔（秒）
    private let poiCacheUpdateInterval: TimeInterval = 30 // POI 缓存更新间隔（秒）
    private var lastPOICacheUpdate: Date = .distantPast

    /// 触发 POI 检测的移动距离阈值（米）
    private let detectionMovementThreshold: Double = 50

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

            // 保存用户 ID
            currentUserId = userId

            // 重置本次探索统计
            poisDiscoveredThisSession = 0

            // 初始化检测位置（首次启动立即触发一次检测）
            lastDetectionLocation = nil

            // 获取附近POI
            await updatePOICache(location: location)
            lastPOICacheUpdate = Date()

            // 加载已发现的POI列表
            await loadDiscoveredPOIIds(userId: userId)

            // 设置探索状态
            isExploring = true

            // 启动位置追踪
            startLocationTracking()

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

            // 停止位置追踪
            stopLocationTracking()

            // 计算探索奖励
            let rewards = LocalExplorationRewardCalculator.calculateRewards(
                distanceWalked: explorationStats.totalDistance,
                durationSeconds: Int(duration),
                poisDiscovered: poisDiscoveredThisSession
            )

            // 创建探索结果
            let result = ExplorationResult(
                sessionId: sessionId,
                duration: duration,
                totalDistance: explorationStats.totalDistance,
                poisDiscovered: poisDiscoveredThisSession,
                rewards: rewards
            )

            // 保存本次发现数量用于日志
            let discoveredCount = poisDiscoveredThisSession

            // 重置状态
            isExploring = false
            currentSessionId = nil
            currentUserId = nil
            explorationStats = ExplorationStats()
            poisDiscoveredThisSession = 0
            nearbyPOIs = []
            discoveredPOIIds = []
            lastDetectionLocation = nil

            // 重置发现管理器
            discoveryManager.reset()

            print("✅ 结束探索，时长: \(Int(duration))秒，距离: \(Int(result.totalDistance))米，发现: \(discoveredCount)个POI")

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

    // MARK: - 位置追踪

    /// 启动位置追踪定时器
    private func startLocationTracking() {
        stopLocationTracking() // 确保没有重复的定时器

        print("🔄 启动位置追踪，间隔: \(trackingInterval)秒")

        locationTrackingTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performLocationCheck()
            }
        }
    }

    /// 停止位置追踪定时器
    private func stopLocationTracking() {
        locationTrackingTimer?.invalidate()
        locationTrackingTimer = nil
        print("⏹️ 停止位置追踪")
    }

    /// 执行位置检测
    private func performLocationCheck() async {
        guard isExploring,
              let location = explorationStats.lastLocation,
              let userId = currentUserId else {
            return
        }

        // 定期更新 POI 缓存
        if Date().timeIntervalSince(lastPOICacheUpdate) > poiCacheUpdateInterval {
            await updatePOICache(location: location)
            lastPOICacheUpdate = Date()
        }

        // 清理远离的已触发 POI
        discoveryManager.clearDistantTriggeredPOIs(currentLocation: location, nearbyPOIs: nearbyPOIs)

        // 检查是否需要触发 POI 检测（距离变化 > 50米 或 首次检测）
        let shouldCheckPOIs: Bool
        if let lastDetection = lastDetectionLocation {
            let distanceMoved = calculateDistance(from: lastDetection, to: location)
            shouldCheckPOIs = distanceMoved >= detectionMovementThreshold
            if shouldCheckPOIs {
                print("📍 移动距离达到 \(Int(distanceMoved))米，触发 POI 检测")
            }
        } else {
            // 首次检测
            shouldCheckPOIs = true
            print("📍 首次位置检测")
        }

        // 只有满足距离条件时才进行 POI 检测
        if shouldCheckPOIs {
            lastDetectionLocation = location
            await trackLocation(location, userId: userId)
        }
    }

    /// 追踪位置并检测 POI 发现（批量模式）
    /// - Parameters:
    ///   - location: 当前位置
    ///   - userId: 用户 ID
    func trackLocation(_ location: CLLocationCoordinate2D, userId: UUID) async {
        // 批量检查接近的 POI（100米内所有未发现的）
        let nearbyUndiscoveredPOIs = discoveryManager.checkProximityBatch(
            currentLocation: location,
            nearbyPOIs: nearbyPOIs,
            discoveredPOIIds: discoveredPOIIds
        )

        guard !nearbyUndiscoveredPOIs.isEmpty else { return }

        // 批量触发发现
        do {
            let results = try await discoveryManager.triggerBatchDiscovery(
                pois: nearbyUndiscoveredPOIs,
                userId: userId
            )

            // 更新已发现列表和计数
            for result in results {
                discoveredPOIIds.insert(result.poi.id)
                poisDiscoveredThisSession += 1
            }

            print("🎉 批量发现 \(results.count) 个 POI，本次探索共发现: \(poisDiscoveredThisSession) 个")

        } catch {
            print("❌ 批量触发发现失败: \(error)")
        }
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

// MARK: - Quick Test Mode (DEBUG)

#if DEBUG
extension ExplorationManager {
    /// 快速测试探索回调类型
    typealias QuickTestProgressCallback = (QuickTestProgress) -> Void

    /// 快速测试进度
    enum QuickTestProgress {
        case started
        case discoveredPOI(Int)  // 发现第几个POI
        case walking(Double)     // 当前行走距离
        case finishing
        case completed(ExplorationResult)
        case failed(Error)
    }

    /// 快速测试探索（约10秒完成）
    /// 自动模拟：启动探索 → 发现POI → 行走 → 结束探索
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - location: 起始位置
    ///   - onProgress: 进度回调
    /// - Returns: 探索结果
    func startQuickTestExploration(
        userId: UUID,
        location: CLLocationCoordinate2D,
        onProgress: QuickTestProgressCallback? = nil
    ) async throws -> ExplorationResult {
        print("🧪 [快速测试] 开始快速测试探索...")

        // 1. 启动探索
        try await startExploration(userId: userId, location: location)
        onProgress?(.started)
        print("🧪 [快速测试] 探索已启动")

        // 2. 等待2秒，模拟发现第一个POI
        try await Task.sleep(nanoseconds: 2_000_000_000)

        if let _ = await simulateDiscoveryIfAvailable(userId: userId) {
            onProgress?(.discoveredPOI(1))
            print("🧪 [快速测试] 发现第1个POI")
        }

        // 3. 模拟行走200米
        explorationStats.totalDistance = 200
        onProgress?(.walking(200))
        print("🧪 [快速测试] 已行走200米")

        // 4. 再等待2秒，模拟发现第二个POI
        try await Task.sleep(nanoseconds: 2_000_000_000)

        if let _ = await simulateDiscoveryIfAvailable(userId: userId) {
            onProgress?(.discoveredPOI(2))
            print("🧪 [快速测试] 发现第2个POI")
        }

        // 5. 模拟继续行走到500米
        explorationStats.totalDistance = 500
        onProgress?(.walking(500))
        print("🧪 [快速测试] 已行走500米")

        // 6. 再等待2秒
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // 7. 设置最终模拟数据
        explorationStats.totalDistance = 500

        // 8. 准备结束
        onProgress?(.finishing)
        print("🧪 [快速测试] 准备结束探索...")

        // 9. 结束探索并返回结果
        let result = try await stopExploration(location: location)
        onProgress?(.completed(result))
        print("🧪 [快速测试] 探索完成！获得 \(result.rewards.count) 种物品")

        return result
    }

    /// 尝试模拟发现POI（如果有可用的）
    private func simulateDiscoveryIfAvailable(userId: UUID) async -> DiscoveryResult? {
        // 检查是否有可发现的POI
        guard !nearbyPOIs.isEmpty else {
            print("🧪 [快速测试] 没有附近的POI可以发现")
            return nil
        }

        let success = await discoveryManager.simulateDiscoveryNearest(
            nearbyPOIs: nearbyPOIs,
            discoveredPOIIds: discoveredPOIIds,
            userId: userId
        )

        if success, let result = discoveryManager.lastDiscoveryResult {
            // 更新已发现列表
            discoveredPOIIds.insert(result.poi.id)
            poisDiscoveredThisSession += 1
            return result
        }

        return nil
    }

    /// 快速测试探索（简化版，无回调）
    func startQuickTestExplorationSimple(
        userId: UUID,
        location: CLLocationCoordinate2D
    ) async throws -> ExplorationResult {
        return try await startQuickTestExploration(
            userId: userId,
            location: location,
            onProgress: nil
        )
    }
}
#endif
