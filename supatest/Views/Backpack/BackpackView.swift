//
//  BackpackView.swift
//  supatest
//
//  EarthLord Game - Backpack View
//  背包视图
//

import SwiftUI
import SwiftData

// MARK: - BackpackView

struct BackpackView: View {
    @ObservedObject var inventoryManager = LocalInventoryManager.shared

    /// 选中的物品（用于显示详情）
    @State private var selectedItem: LocalInventoryItem?

    /// 显示物品详情
    @State private var showItemDetail: Bool = false

    /// 网格列配置
    private let columns = [
        GridItem(.adaptive(minimum: 70, maximum: 90), spacing: 12)
    ]

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            if inventoryManager.items.isEmpty {
                emptyBackpackView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 背包统计
                        backpackHeader

                        // 物品网格
                        itemsGrid
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(Text("背包"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showItemDetail) {
            if let item = selectedItem {
                ItemDetailSheet(item: item)
            }
        }
        .task {
            await inventoryManager.loadItems()
        }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        inventoryManager.addTestItems()
                    } label: {
                        Label("添加测试物品", systemImage: "plus.circle")
                    }

                    Button(role: .destructive) {
                        inventoryManager.clearAll()
                    } label: {
                        Label("清空背包", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(.purple)
                }
            }
        }
        #endif
    }

    // MARK: - Empty View

    private var emptyBackpackView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("背包是空的")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.text)

            Text("开始探索来收集物资吧！")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Header

    private var backpackHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("物品总数")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(inventoryManager.totalItemCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("物品种类")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("\(inventoryManager.items.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Items Grid

    private var itemsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(inventoryManager.items) { item in
                ItemGridCell(item: item)
                    .onTapGesture {
                        selectedItem = item
                        showItemDetail = true
                    }
            }
        }
    }
}

// MARK: - ItemGridCell

struct ItemGridCell: View {
    let item: LocalInventoryItem

    var body: some View {
        VStack(spacing: 4) {
            // 物品图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(width: 70, height: 70)

                Image(systemName: item.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(qualityColor)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(qualityColor.opacity(0.6), lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                // 数量徽章
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(8)
                        .offset(x: 4, y: -4)
                }
            }

            // 物品名称
            Text(item.localizedName)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.text)
                .lineLimit(1)
        }
    }

    private var qualityColor: Color {
        switch item.qualityTier {
        case .excellent: return .purple
        case .good: return .blue
        case .normal: return .green
        case .damaged: return .gray
        }
    }
}

// MARK: - ItemDetailSheet

struct ItemDetailSheet: View {
    let item: LocalInventoryItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 物品图标
                    itemIcon
                        .padding(.top, 20)

                    // 物品名称
                    Text(item.localizedName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.text)

                    // 物品属性
                    itemProperties

                    Spacer()

                    // 关闭按钮
                    Button {
                        dismiss()
                    } label: {
                        Text("关闭")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(ApocalypseTheme.primary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(Text("物品详情"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private var itemIcon: some View {
        ZStack {
            Circle()
                .fill(qualityColor.opacity(0.2))
                .frame(width: 120, height: 120)

            Circle()
                .fill(ApocalypseTheme.cardBackground)
                .frame(width: 100, height: 100)

            Image(systemName: item.iconName)
                .font(.system(size: 44))
                .foregroundColor(qualityColor)
        }
        .overlay(
            Circle()
                .stroke(qualityColor, lineWidth: 3)
                .frame(width: 100, height: 100)
        )
    }

    private var itemProperties: some View {
        VStack(spacing: 12) {
            // 数量
            propertyRow(
                icon: "number.circle.fill",
                title: "数量",
                value: "×\(item.quantity)"
            )

            // 品质
            propertyRow(
                icon: "star.circle.fill",
                title: "品质",
                value: item.qualityDescription,
                valueColor: qualityColor
            )

            // 品质数值
            propertyRow(
                icon: "percent",
                title: "品质值",
                value: String(format: "%.0f%%", item.quality * 100)
            )

            // 来源
            propertyRow(
                icon: "mappin.circle.fill",
                title: "来源",
                value: item.sourceType.localizedName
            )

            // 获取时间
            propertyRow(
                icon: "clock.fill",
                title: "获取时间",
                value: formattedDate(item.createdAt)
            )
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    private func propertyRow(
        icon: String,
        title: LocalizedStringKey,
        value: String,
        valueColor: Color = ApocalypseTheme.text
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)

            Text(title)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }

    private var qualityColor: Color {
        switch item.qualityTier {
        case .excellent: return .purple
        case .good: return .blue
        case .normal: return .green
        case .damaged: return .gray
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Backpack View") {
    NavigationStack {
        BackpackView()
    }
}

#Preview("Item Detail") {
    let item = LocalInventoryItem(
        itemId: "rare_material",
        quantity: 2,
        quality: 0.95,
        source: "exploration:test-session"
    )

    ItemDetailSheet(item: item)
}
