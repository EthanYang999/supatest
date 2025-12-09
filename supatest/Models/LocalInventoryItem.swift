//
//  LocalInventoryItem.swift
//  supatest
//
//  EarthLord Game - Local Inventory Item Model
//  本地背包物品模型（SwiftData）
//

import Foundation
import SwiftData

// MARK: - LocalInventoryItem

@Model
class LocalInventoryItem {
    /// 唯一标识符
    @Attribute(.unique) var id: UUID

    /// 物品类型ID
    var itemId: String

    /// 数量
    var quantity: Int

    /// 品质（0.5-1.0）
    var quality: Double

    /// 来源（"exploration:sessionId" 或 "poi:poiId"）
    var source: String

    /// 创建时间
    var createdAt: Date

    /// 是否已同步到服务器
    var isSynced: Bool

    // MARK: - 初始化

    init(itemId: String, quantity: Int, quality: Double, source: String) {
        self.id = UUID()
        self.itemId = itemId
        self.quantity = quantity
        self.quality = quality
        self.source = source
        self.createdAt = Date()
        self.isSynced = false
    }

    // MARK: - 计算属性

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

    /// 品质等级
    var qualityTier: QualityTier {
        switch quality {
        case 0.9...1.0: return .excellent
        case 0.75..<0.9: return .good
        case 0.6..<0.75: return .normal
        default: return .damaged
        }
    }

    /// 来源类型
    var sourceType: SourceType {
        if source.hasPrefix("exploration:") {
            return .exploration
        } else if source.hasPrefix("poi:") {
            return .poi
        } else {
            return .unknown
        }
    }

    /// 来源ID
    var sourceId: String {
        let parts = source.split(separator: ":")
        return parts.count > 1 ? String(parts[1]) : source
    }
}

// MARK: - QualityTier

/// 品质等级枚举
enum QualityTier: String, CaseIterable {
    case excellent  // 精良
    case good       // 优质
    case normal     // 普通
    case damaged    // 破损

    var localizedName: String {
        switch self {
        case .excellent: return String(localized: "精良")
        case .good: return String(localized: "优质")
        case .normal: return String(localized: "普通")
        case .damaged: return String(localized: "破损")
        }
    }

    var colorName: String {
        switch self {
        case .excellent: return "purple"
        case .good: return "blue"
        case .normal: return "green"
        case .damaged: return "gray"
        }
    }
}

// MARK: - SourceType

/// 来源类型枚举
enum SourceType {
    case exploration
    case poi
    case unknown

    var localizedName: String {
        switch self {
        case .exploration: return String(localized: "探索获得")
        case .poi: return String(localized: "地点搜刮")
        case .unknown: return String(localized: "未知来源")
        }
    }
}
