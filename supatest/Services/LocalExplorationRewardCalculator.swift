//
//  LocalExplorationRewardCalculator.swift
//  supatest
//
//  EarthLord Game - Exploration Reward Calculator
//  计算探索结束时的本地奖励
//

import Foundation

// MARK: - RewardItem

/// 奖励物品
struct RewardItem: Identifiable {
    let id = UUID()
    let itemId: String
    let quantity: Int
    let quality: Double  // 0.5-1.0

    /// 物品本地化名称
    var localizedName: String {
        switch itemId {
        case "wood": return String(localized: "木材")
        case "metal": return String(localized: "金属")
        case "cloth": return String(localized: "布料")
        case "water_bottle": return String(localized: "水瓶")
        case "canned_food": return String(localized: "罐头食品")
        case "bandage": return String(localized: "绷带")
        case "medicine": return String(localized: "药品")
        case "fuel": return String(localized: "燃料")
        case "electronics": return String(localized: "电子元件")
        case "weapon_parts": return String(localized: "武器零件")
        case "rare_material": return String(localized: "稀有材料")
        default: return itemId
        }
    }

    /// 物品图标名称
    var iconName: String {
        switch itemId {
        case "wood": return "tree.fill"
        case "metal": return "cube.fill"
        case "cloth": return "tshirt.fill"
        case "water_bottle": return "drop.fill"
        case "canned_food": return "takeoutbag.and.cup.and.straw.fill"
        case "bandage": return "bandage.fill"
        case "medicine": return "pills.fill"
        case "fuel": return "fuelpump.fill"
        case "electronics": return "cpu.fill"
        case "weapon_parts": return "wrench.and.screwdriver.fill"
        case "rare_material": return "sparkles"
        default: return "questionmark.circle.fill"
        }
    }

    /// 品质等级描述
    var qualityDescription: String {
        switch quality {
        case 0.9...1.0: return String(localized: "精良")
        case 0.75..<0.9: return String(localized: "优质")
        case 0.6..<0.75: return String(localized: "普通")
        default: return String(localized: "破损")
        }
    }

    /// 品质对应颜色（用于UI）
    var qualityColorName: String {
        switch quality {
        case 0.9...1.0: return "purple"  // 精良 - 紫色
        case 0.75..<0.9: return "blue"   // 优质 - 蓝色
        case 0.6..<0.75: return "green"  // 普通 - 绿色
        default: return "gray"           // 破损 - 灰色
        }
    }
}

// MARK: - LootPool

/// 掉落池配置
struct LootPool {
    /// 物品及其权重
    let items: [(itemId: String, weight: Int)]
    /// 最小掉落数量
    let minItems: Int
    /// 最大掉落数量
    let maxItems: Int

    /// 总权重
    var totalWeight: Int {
        items.reduce(0) { $0 + $1.weight }
    }

    /// 根据权重随机选择一个物品
    /// - Parameter rarityBonus: 稀有度加成（0-1），越高稀有物品概率越大
    /// - Returns: 选中的物品ID
    func randomItem(rarityBonus: Double = 0) -> String {
        let adjustedItems = items.map { item -> (itemId: String, weight: Int) in
            // 稀有物品（权重低于15）获得加成
            if item.weight < 15 {
                let bonus = Int(Double(item.weight) * rarityBonus * 2)
                return (item.itemId, item.weight + bonus)
            }
            return item
        }

        let totalWeight = adjustedItems.reduce(0) { $0 + $1.weight }
        var randomValue = Int.random(in: 0..<totalWeight)

        for item in adjustedItems {
            randomValue -= item.weight
            if randomValue < 0 {
                return item.itemId
            }
        }

        return items.last?.itemId ?? "wood"
    }
}

// MARK: - LocalExplorationRewardCalculator

/// 探索奖励计算器
enum LocalExplorationRewardCalculator {

    // MARK: - 掉落池定义

    /// 基础掉落池（走路获得）
    static let basicPool = LootPool(
        items: [
            ("wood", 30),
            ("metal", 20),
            ("cloth", 20),
            ("water_bottle", 15),
            ("canned_food", 10),
            ("bandage", 5)
        ],
        minItems: 1,
        maxItems: 3
    )

    /// 时间奖励掉落池（探索时间奖励）
    static let timePool = LootPool(
        items: [
            ("water_bottle", 25),
            ("canned_food", 25),
            ("bandage", 20),
            ("medicine", 15),
            ("fuel", 10),
            ("electronics", 5)
        ],
        minItems: 1,
        maxItems: 2
    )

    /// POI发现奖励掉落池
    static let poiPool = LootPool(
        items: [
            ("metal", 20),
            ("electronics", 20),
            ("medicine", 20),
            ("weapon_parts", 15),
            ("fuel", 15),
            ("rare_material", 10)
        ],
        minItems: 1,
        maxItems: 2
    )

    // MARK: - 常量

    /// 每多少米获得一次基础抽取
    private static let metersPerDraw: Double = 100

    /// 每多少秒获得一次时间抽取
    private static let secondsPerTimeDraw: Int = 300  // 5分钟

    /// 最大基础抽取次数
    private static let maxBasicDraws: Int = 20

    /// 最大时间抽取次数
    private static let maxTimeDraws: Int = 10

    // MARK: - 计算方法

    /// 计算探索奖励
    /// - Parameters:
    ///   - distanceWalked: 行走距离（米）
    ///   - durationSeconds: 探索时长（秒）
    ///   - poisDiscovered: 发现的POI数量
    /// - Returns: 奖励物品列表
    static func calculateRewards(
        distanceWalked: Double,
        durationSeconds: Int,
        poisDiscovered: Int
    ) -> [RewardItem] {
        var rewards: [RewardItem] = []

        // 计算稀有度加成（基于距离）
        let rarityBonus = calculateRarityBonus(distance: distanceWalked)

        // 计算品质加成（基于时间）
        let qualityBonus = calculateQualityBonus(duration: durationSeconds)

        // 1. 基础奖励（距离）
        let basicDraws = min(Int(distanceWalked / metersPerDraw), maxBasicDraws)
        for _ in 0..<basicDraws {
            let itemId = basicPool.randomItem(rarityBonus: rarityBonus)
            let quality = generateQuality(baseBonus: qualityBonus * 0.5)
            rewards.append(RewardItem(itemId: itemId, quantity: 1, quality: quality))
        }

        // 2. 时间奖励
        let timeDraws = min(durationSeconds / secondsPerTimeDraw, maxTimeDraws)
        for _ in 0..<timeDraws {
            let itemId = timePool.randomItem(rarityBonus: rarityBonus)
            let quality = generateQuality(baseBonus: qualityBonus)
            rewards.append(RewardItem(itemId: itemId, quantity: 1, quality: quality))
        }

        // 3. POI发现奖励
        for _ in 0..<poisDiscovered {
            let itemId = poiPool.randomItem(rarityBonus: rarityBonus + 0.2)  // POI奖励额外稀有度加成
            let quality = generateQuality(baseBonus: qualityBonus + 0.1)     // POI奖励额外品质加成
            rewards.append(RewardItem(itemId: itemId, quantity: 1, quality: quality))
        }

        // 合并相同物品
        return mergeRewards(rewards)
    }

    /// 计算稀有度加成（基于距离）
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 加成值（0-0.5）
    private static func calculateRarityBonus(distance: Double) -> Double {
        // 每500米增加0.05稀有度，最高0.5
        return min(distance / 500 * 0.05, 0.5)
    }

    /// 计算品质加成（基于时间）
    /// - Parameter duration: 探索时长（秒）
    /// - Returns: 加成值（0-0.3）
    private static func calculateQualityBonus(duration: Int) -> Double {
        // 每10分钟增加0.05品质，最高0.3
        return min(Double(duration) / 600 * 0.05, 0.3)
    }

    /// 生成随机品质
    /// - Parameter baseBonus: 基础加成
    /// - Returns: 品质值（0.5-1.0）
    private static func generateQuality(baseBonus: Double) -> Double {
        let base = 0.5 + baseBonus
        let randomPart = Double.random(in: 0...0.3)
        return min(base + randomPart, 1.0)
    }

    /// 合并相同物品
    /// - Parameter rewards: 原始奖励列表
    /// - Returns: 合并后的奖励列表
    private static func mergeRewards(_ rewards: [RewardItem]) -> [RewardItem] {
        var merged: [String: (quantity: Int, totalQuality: Double, count: Int)] = [:]

        for reward in rewards {
            if var existing = merged[reward.itemId] {
                existing.quantity += reward.quantity
                existing.totalQuality += reward.quality
                existing.count += 1
                merged[reward.itemId] = existing
            } else {
                merged[reward.itemId] = (reward.quantity, reward.quality, 1)
            }
        }

        return merged.map { itemId, data in
            let averageQuality = data.totalQuality / Double(data.count)
            return RewardItem(itemId: itemId, quantity: data.quantity, quality: averageQuality)
        }.sorted { $0.quantity > $1.quantity }  // 按数量排序
    }

    // MARK: - 调试方法

    #if DEBUG
    /// 测试奖励分布
    /// - Parameters:
    ///   - iterations: 测试次数
    ///   - distance: 模拟距离
    ///   - duration: 模拟时长
    ///   - pois: 模拟POI数量
    static func testRewardDistribution(
        iterations: Int = 1000,
        distance: Double = 1000,
        duration: Int = 1800,
        pois: Int = 3
    ) {
        print("========== 奖励分布测试 ==========")
        print("测试次数: \(iterations)")
        print("模拟距离: \(Int(distance))米")
        print("模拟时长: \(duration / 60)分钟")
        print("发现POI: \(pois)个")
        print("==================================")

        var itemCounts: [String: Int] = [:]
        var totalItems = 0
        var qualitySum: [String: Double] = [:]
        var qualityCount: [String: Int] = [:]

        for _ in 0..<iterations {
            let rewards = calculateRewards(
                distanceWalked: distance,
                durationSeconds: duration,
                poisDiscovered: pois
            )

            for reward in rewards {
                itemCounts[reward.itemId, default: 0] += reward.quantity
                totalItems += reward.quantity
                qualitySum[reward.itemId, default: 0] += reward.quality * Double(reward.quantity)
                qualityCount[reward.itemId, default: 0] += reward.quantity
            }
        }

        print("\n物品分布统计:")
        print("---------------------------------")

        let sortedItems = itemCounts.sorted { $0.value > $1.value }
        for (itemId, count) in sortedItems {
            let percentage = Double(count) / Double(totalItems) * 100
            let avgQuality = qualitySum[itemId, default: 0] / Double(qualityCount[itemId, default: 1])
            print(String(format: "%-15s: %5d (%5.1f%%)  平均品质: %.2f",
                        itemId, count, percentage, avgQuality))
        }

        print("---------------------------------")
        print("总物品数: \(totalItems)")
        print("平均每次: \(Double(totalItems) / Double(iterations))")
        print("==================================\n")
    }

    /// 测试不同距离的稀有度
    static func testRarityByDistance() {
        print("========== 距离稀有度测试 ==========")

        let distances: [Double] = [100, 500, 1000, 2000, 5000]

        for distance in distances {
            let bonus = calculateRarityBonus(distance: distance)
            print("距离 \(Int(distance))米 -> 稀有度加成: \(String(format: "%.2f", bonus))")
        }

        print("====================================\n")
    }

    /// 测试不同时长的品质
    static func testQualityByDuration() {
        print("========== 时长品质测试 ==========")

        let durations: [Int] = [300, 600, 1200, 1800, 3600]

        for duration in durations {
            let bonus = calculateQualityBonus(duration: duration)
            print("时长 \(duration / 60)分钟 -> 品质加成: \(String(format: "%.2f", bonus))")
        }

        print("==================================\n")
    }

    /// 运行所有测试
    static func runAllTests() {
        testRarityByDistance()
        testQualityByDuration()
        testRewardDistribution(iterations: 1000, distance: 500, duration: 600, pois: 1)
        testRewardDistribution(iterations: 1000, distance: 2000, duration: 1800, pois: 5)
    }
    #endif
}

// MARK: - 奖励汇总

/// 探索奖励汇总
struct ExplorationRewardSummary {
    let rewards: [RewardItem]
    let distanceWalked: Double
    let durationSeconds: Int
    let poisDiscovered: Int

    /// 总物品数量
    var totalItemCount: Int {
        rewards.reduce(0) { $0 + $1.quantity }
    }

    /// 平均品质
    var averageQuality: Double {
        guard !rewards.isEmpty else { return 0 }
        let totalQuality = rewards.reduce(0.0) { $0 + $1.quality * Double($1.quantity) }
        return totalQuality / Double(totalItemCount)
    }

    /// 格式化的探索时长
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes > 0 {
            return String(localized: "\(minutes)分\(seconds)秒")
        } else {
            return String(localized: "\(seconds)秒")
        }
    }

    /// 格式化的行走距离
    var formattedDistance: String {
        if distanceWalked >= 1000 {
            return String(format: "%.1f km", distanceWalked / 1000)
        } else {
            return String(format: "%.0f m", distanceWalked)
        }
    }
}
