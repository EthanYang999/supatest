//
//  LocalInventoryManager.swift
//  supatest
//
//  EarthLord Game - Local Inventory Manager
//  本地背包管理器（SwiftData）
//

import Foundation
import SwiftData
import SwiftUI
import Combine

// MARK: - LocalInventoryManager

@MainActor
class LocalInventoryManager: ObservableObject {

    // MARK: - 单例

    static let shared = LocalInventoryManager()

    // MARK: - 属性

    /// SwiftData 模型容器
    let modelContainer: ModelContainer

    /// 模型上下文
    var modelContext: ModelContext {
        modelContainer.mainContext
    }

    /// 背包物品列表（用于 UI 绑定）
    @Published var items: [LocalInventoryItem] = []

    /// 总物品数量
    @Published var totalItemCount: Int = 0

    // MARK: - 初始化

    private init() {
        do {
            let schema = Schema([LocalInventoryItem.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ LocalInventoryManager 初始化成功")

            // 加载现有物品
            Task {
                await loadItems()
            }
        } catch {
            fatalError("❌ 无法创建 ModelContainer: \(error)")
        }
    }

    // MARK: - 公开方法

    /// 添加物品到背包
    /// - Parameters:
    ///   - itemId: 物品ID
    ///   - quantity: 数量
    ///   - quality: 品质
    ///   - source: 来源
    func addItem(itemId: String, quantity: Int, quality: Double, source: String) {
        let item = LocalInventoryItem(
            itemId: itemId,
            quantity: quantity,
            quality: quality,
            source: source
        )

        modelContext.insert(item)

        do {
            try modelContext.save()
            print("✅ 添加物品: \(itemId) x\(quantity)")

            // 刷新列表
            Task {
                await loadItems()
            }
        } catch {
            print("❌ 保存物品失败: \(error)")
        }
    }

    /// 批量添加奖励物品
    /// - Parameters:
    ///   - rewards: 奖励物品列表
    ///   - source: 来源
    func addRewards(_ rewards: [RewardItem], source: String) {
        for reward in rewards {
            let item = LocalInventoryItem(
                itemId: reward.itemId,
                quantity: reward.quantity,
                quality: reward.quality,
                source: source
            )
            modelContext.insert(item)
        }

        do {
            try modelContext.save()
            print("✅ 批量添加 \(rewards.count) 种物品")

            // 刷新列表
            Task {
                await loadItems()
            }
        } catch {
            print("❌ 批量保存物品失败: \(error)")
        }
    }

    /// 获取所有物品
    /// - Returns: 物品列表
    func getItems() -> [LocalInventoryItem] {
        let descriptor = FetchDescriptor<LocalInventoryItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ 获取物品失败: \(error)")
            return []
        }
    }

    /// 获取指定物品的总数量
    /// - Parameter itemId: 物品ID
    /// - Returns: 总数量
    func getItemCount(itemId: String) -> Int {
        let predicate = #Predicate<LocalInventoryItem> { item in
            item.itemId == itemId
        }
        let descriptor = FetchDescriptor<LocalInventoryItem>(predicate: predicate)

        do {
            let items = try modelContext.fetch(descriptor)
            return items.reduce(0) { $0 + $1.quantity }
        } catch {
            print("❌ 获取物品数量失败: \(error)")
            return 0
        }
    }

    /// 获取按物品ID分组的汇总
    /// - Returns: 汇总字典 [itemId: (totalQuantity, averageQuality)]
    func getItemsSummary() -> [String: (quantity: Int, avgQuality: Double)] {
        let items = getItems()
        var summary: [String: (quantity: Int, totalQuality: Double, count: Int)] = [:]

        for item in items {
            if var existing = summary[item.itemId] {
                existing.quantity += item.quantity
                existing.totalQuality += item.quality * Double(item.quantity)
                existing.count += item.quantity
                summary[item.itemId] = existing
            } else {
                summary[item.itemId] = (item.quantity, item.quality * Double(item.quantity), item.quantity)
            }
        }

        return summary.mapValues { data in
            (data.quantity, data.totalQuality / Double(data.count))
        }
    }

    /// 删除物品
    /// - Parameter id: 物品ID
    func removeItem(id: UUID) {
        let predicate = #Predicate<LocalInventoryItem> { item in
            item.id == id
        }
        let descriptor = FetchDescriptor<LocalInventoryItem>(predicate: predicate)

        do {
            if let item = try modelContext.fetch(descriptor).first {
                modelContext.delete(item)
                try modelContext.save()
                print("✅ 删除物品: \(item.itemId)")

                // 刷新列表
                Task {
                    await loadItems()
                }
            }
        } catch {
            print("❌ 删除物品失败: \(error)")
        }
    }

    /// 清空所有物品
    func clearAll() {
        let items = getItems()
        for item in items {
            modelContext.delete(item)
        }

        do {
            try modelContext.save()
            print("✅ 清空背包")

            // 刷新列表
            Task {
                await loadItems()
            }
        } catch {
            print("❌ 清空背包失败: \(error)")
        }
    }

    /// 刷新物品列表
    func loadItems() async {
        items = getItems()
        totalItemCount = items.reduce(0) { $0 + $1.quantity }
    }

    // MARK: - 调试方法

    #if DEBUG
    /// 添加测试物品
    func addTestItems() {
        let testItems: [(String, Int, Double)] = [
            ("wood", 5, 0.7),
            ("metal", 3, 0.85),
            ("cloth", 2, 0.6),
            ("water_bottle", 1, 0.95),
            ("bandage", 2, 0.75),
            ("electronics", 1, 0.9),
            ("rare_material", 1, 0.98)
        ]

        for (itemId, quantity, quality) in testItems {
            addItem(itemId: itemId, quantity: quantity, quality: quality, source: "debug:test")
        }

        print("✅ 添加测试物品完成")
    }
    #endif
}
