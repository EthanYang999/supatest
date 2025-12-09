//
//  DiscoveryManager.swift
//  supatest
//
//  EarthLord Game - Discovery Manager
//  负责POI发现检测和触发
//

import Foundation
import CoreLocation
import Combine
import UIKit
import Supabase

// MARK: - Discovery Result

/// 发现结果
struct DiscoveryResult {
    let poi: POI
    let isFirstDiscovery: Bool  // 是否全服首次发现
    let timestamp: Date
}

// MARK: - RPC Response

private struct MarkDiscoveredResponse: Decodable {
    let success: Bool
    let message: String?
}

// MARK: - DiscoveryManager

@MainActor
class DiscoveryManager: ObservableObject {
    // MARK: - 单例

    static let shared = DiscoveryManager()

    private init() {}

    // MARK: - 常量

    /// 触发发现的距离阈值（米）
    private let triggerDistance: Double = 100

    /// 清除触发状态的距离阈值（米）
    private let clearDistance: Double = 200

    // MARK: - 发布属性

    /// 待显示的发现
    @Published var pendingDiscovery: POI?

    /// 是否显示发现弹窗
    @Published var showDiscoveryAlert: Bool = false

    /// 最近的发现结果
    @Published var lastDiscoveryResult: DiscoveryResult?

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 触发管理

    /// 已触发过的 POI ID（防止重复触发）
    private var triggeredPOIIds: Set<String> = []

    // MARK: - 核心方法

    /// 检查接近的 POI
    /// - Parameters:
    ///   - currentLocation: 当前位置
    ///   - nearbyPOIs: 附近的 POI 列表
    ///   - discoveredPOIIds: 已发现的 POI ID 集合
    /// - Returns: 100米内最近的未发现 POI（如果有）
    func checkProximity(
        currentLocation: CLLocationCoordinate2D,
        nearbyPOIs: [POI],
        discoveredPOIIds: Set<String>
    ) -> POI? {
        var closestPOI: POI?
        var closestDistance: Double = triggerDistance

        for poi in nearbyPOIs {
            // 跳过已发现的 POI
            if discoveredPOIIds.contains(poi.id) {
                continue
            }

            // 跳过已触发过的 POI
            if triggeredPOIIds.contains(poi.id) {
                continue
            }

            // 计算距离
            let poiLocation = CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)
            let dist = distance(from: currentLocation, to: poiLocation)

            // 找到100米内最近的
            if dist < closestDistance {
                closestDistance = dist
                closestPOI = poi
            }
        }

        if let poi = closestPOI {
            print("📍 发现接近的 POI: \(poi.name ?? poi.id)，距离: \(Int(closestDistance))米")
        }

        return closestPOI
    }

    /// 触发 POI 发现
    /// - Parameters:
    ///   - poi: 要发现的 POI
    ///   - userId: 用户 ID
    /// - Returns: 发现结果
    func triggerDiscovery(poi: POI, userId: UUID) async throws -> DiscoveryResult {
        print("🎯 触发发现 POI: \(poi.name ?? poi.id)")

        // 添加到已触发集合
        triggeredPOIIds.insert(poi.id)

        errorMessage = nil

        do {
            // 调用 RPC 标记 POI 为已发现
            let params: [String: AnyJSON] = [
                "p_poi_id": try AnyJSON(poi.id),
                "p_user_id": try AnyJSON(userId.uuidString)
            ]

            let response: MarkDiscoveredResponse = try await supabase.rpc(
                "mark_poi_discovered",
                params: params
            ).execute().value

            // 判断是否全服首次发现
            let isFirstDiscovery = response.success

            // 创建发现结果
            let result = DiscoveryResult(
                poi: poi,
                isFirstDiscovery: isFirstDiscovery,
                timestamp: Date()
            )

            // 更新状态
            lastDiscoveryResult = result
            pendingDiscovery = poi
            showDiscoveryAlert = true

            // 触发震动反馈
            triggerHapticFeedback()

            print("✅ POI 发现成功: \(poi.name ?? poi.id)，首次发现: \(isFirstDiscovery)")

            return result

        } catch {
            // 发生错误时，从已触发集合中移除，允许重试
            triggeredPOIIds.remove(poi.id)

            errorMessage = error.localizedDescription
            print("❌ POI 发现失败: \(error)")
            throw error
        }
    }

    /// 清除已触发的 POI（当离开一定距离时）
    /// - Parameters:
    ///   - poiId: POI ID
    ///   - currentLocation: 当前位置
    ///   - poiLocation: POI 位置
    func clearTriggeredPOI(
        poiId: String,
        currentLocation: CLLocationCoordinate2D,
        poiLocation: CLLocationCoordinate2D
    ) {
        let dist = distance(from: currentLocation, to: poiLocation)

        if dist > clearDistance {
            if triggeredPOIIds.contains(poiId) {
                triggeredPOIIds.remove(poiId)
                print("🔄 清除已触发状态: \(poiId)，距离: \(Int(dist))米")
            }
        }
    }

    /// 批量清除远离的已触发 POI
    /// - Parameters:
    ///   - currentLocation: 当前位置
    ///   - nearbyPOIs: 附近的 POI 列表
    func clearDistantTriggeredPOIs(
        currentLocation: CLLocationCoordinate2D,
        nearbyPOIs: [POI]
    ) {
        // 创建 POI 字典方便查找
        let poiDict = Dictionary(uniqueKeysWithValues: nearbyPOIs.map { ($0.id, $0) })

        // 检查所有已触发的 POI
        for poiId in triggeredPOIIds {
            if let poi = poiDict[poiId] {
                let poiLocation = CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)
                clearTriggeredPOI(poiId: poiId, currentLocation: currentLocation, poiLocation: poiLocation)
            }
        }
    }

    /// 关闭发现弹窗
    func dismissDiscoveryAlert() {
        showDiscoveryAlert = false
        pendingDiscovery = nil
    }

    /// 重置所有状态
    func reset() {
        triggeredPOIIds.removeAll()
        pendingDiscovery = nil
        showDiscoveryAlert = false
        lastDiscoveryResult = nil
        errorMessage = nil
        print("🔄 DiscoveryManager 状态已重置")
    }

    // MARK: - 辅助方法

    /// 计算两点之间的距离（米）
    /// - Parameters:
    ///   - from: 起点坐标
    ///   - to: 终点坐标
    /// - Returns: 距离（米）
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// 触发震动反馈
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()

        // 延迟再震动一次，增强效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let generator2 = UIImpactFeedbackGenerator(style: .medium)
            generator2.impactOccurred()
        }
    }

    // MARK: - 调试方法

    /// 获取当前已触发的 POI 数量
    var triggeredCount: Int {
        triggeredPOIIds.count
    }

    /// 检查 POI 是否已触发
    func isTriggered(_ poiId: String) -> Bool {
        triggeredPOIIds.contains(poiId)
    }

    // MARK: - Debug 模拟方法

    #if DEBUG
    /// 模拟发现最近的一个未发现POI
    /// - Parameters:
    ///   - nearbyPOIs: 附近的 POI 列表
    ///   - discoveredPOIIds: 已发现的 POI ID 集合
    ///   - userId: 用户 ID
    /// - Returns: 是否成功模拟发现
    @discardableResult
    func simulateDiscoveryNearest(
        nearbyPOIs: [POI],
        discoveredPOIIds: Set<String>,
        userId: UUID
    ) async -> Bool {
        print("🔧 [DEBUG] 开始模拟发现最近的 POI...")

        // 找到第一个未发现且未触发的 POI
        guard let poi = nearbyPOIs.first(where: {
            !discoveredPOIIds.contains($0.id) && !triggeredPOIIds.contains($0.id)
        }) else {
            print("⚠️ [DEBUG] 没有可发现的 POI")
            return false
        }

        return await simulateDiscovery(poi: poi, userId: userId)
    }

    /// 模拟发现指定POI
    /// - Parameters:
    ///   - poi: 要模拟发现的 POI
    ///   - userId: 用户 ID
    /// - Returns: 是否成功模拟发现
    @discardableResult
    func simulateDiscovery(poi: POI, userId: UUID) async -> Bool {
        print("🔧 [DEBUG] 模拟发现 POI: \(poi.name ?? poi.id)")

        do {
            // 调用真实的发现逻辑（包括数据库写入、震动反馈、弹窗）
            let result = try await triggerDiscovery(poi: poi, userId: userId)
            print("✅ [DEBUG] 模拟发现成功: \(poi.name ?? poi.id)，首次发现: \(result.isFirstDiscovery)")
            return true
        } catch {
            print("❌ [DEBUG] 模拟发现失败: \(error)")
            return false
        }
    }
    #endif
}
