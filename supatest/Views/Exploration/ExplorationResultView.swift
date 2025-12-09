//
//  ExplorationResultView.swift
//  supatest
//
//  EarthLord Game - Exploration Result View
//  探索结束结果页面
//

import SwiftUI

// MARK: - ExplorationResultData

/// 探索结果数据（用于视图显示）
struct ExplorationResultData {
    let sessionId: UUID
    let duration: TimeInterval
    let distance: Double
    let poisDiscovered: Int
    let rewards: [RewardItem]

    /// 格式化的探索时长
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(localized: "\(minutes)分\(seconds)秒")
        } else {
            return String(localized: "\(seconds)秒")
        }
    }

    /// 格式化的行走距离
    var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }

    /// 按稀有度排序的奖励（稀有在前）
    var sortedRewards: [RewardItem] {
        rewards.sorted { item1, item2 in
            // 先按品质降序，再按数量降序
            if item1.quality != item2.quality {
                return item1.quality > item2.quality
            }
            return item1.quantity > item2.quantity
        }
    }
}

// MARK: - ExplorationResultView

struct ExplorationResultView: View {
    let result: ExplorationResultData
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// 卡片是否显示
    @State private var isCardVisible: Bool = false

    /// 已显示的物品索引
    @State private var visibleItemIndices: Set<Int> = []

    /// 背包管理器
    @ObservedObject private var inventoryManager = LocalInventoryManager.shared

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击背景不关闭，必须点收下按钮
                }

            // 结果卡片
            resultCard
                .offset(y: isCardVisible ? 0 : UIScreen.main.bounds.height)
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Result Card

    private var resultCard: some View {
        VStack(spacing: 0) {
            // 拖动指示条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            ScrollView {
                VStack(spacing: 20) {
                    // 标题
                    titleSection

                    // 统计信息
                    statsSection

                    // 分割线
                    Divider()
                        .background(ApocalypseTheme.textSecondary.opacity(0.3))
                        .padding(.horizontal)

                    // 获得物资
                    rewardsSection
                }
                .padding(.bottom, 20)
            }

            // 收下按钮
            confirmButton
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ApocalypseTheme.cardBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 16)
        .padding(.top, 60)
        .padding(.bottom, 40)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ApocalypseTheme.primary.opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(ApocalypseTheme.primary)
                    .frame(width: 70, height: 70)

                Image(systemName: "flag.checkered")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }

            Text("探索结束")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.text)
        }
        .padding(.top, 20)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 16) {
            // 探索时长
            statItem(
                icon: "clock.fill",
                title: "探索时长",
                value: result.formattedDuration
            )

            // 行走距离
            statItem(
                icon: "figure.walk",
                title: "行走距离",
                value: result.formattedDistance
            )

            // 发现废墟
            statItem(
                icon: "building.2.fill",
                title: "发现废墟",
                value: "\(result.poisDiscovered)"
            )
        }
        .padding(.horizontal, 20)
    }

    private func statItem(icon: String, title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Rewards Section

    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text("获得物资")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.text)

                Spacer()

                Text("\(result.rewards.count)种")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.horizontal, 20)

            // 物品列表
            if result.rewards.isEmpty {
                emptyRewardsView
            } else {
                rewardsList
            }
        }
    }

    private var emptyRewardsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("本次探索未获得物资")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var rewardsList: some View {
        VStack(spacing: 12) {
            ForEach(Array(result.sortedRewards.enumerated()), id: \.element.id) { index, reward in
                RewardItemRow(reward: reward, isRare: reward.quality >= 0.9)
                    .opacity(visibleItemIndices.contains(index) ? 1 : 0)
                    .offset(x: visibleItemIndices.contains(index) ? 0 : -20)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            confirmAndClose()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))

                Text("收下")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Animations

    private func startAnimations() {
        // 卡片弹入动画
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isCardVisible = true
        }

        // 物品列表依次淡入
        let sortedRewards = result.sortedRewards
        for (index, _) in sortedRewards.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(index) * 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    _ = visibleItemIndices.insert(index)
                }
            }
        }
    }

    // MARK: - Actions

    private func confirmAndClose() {
        // 将物品添加到背包
        let source = "exploration:\(result.sessionId.uuidString)"
        inventoryManager.addRewards(result.rewards, source: source)

        // 关闭动画
        withAnimation(.easeInOut(duration: 0.3)) {
            isCardVisible = false
        }

        // 延迟执行回调
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onConfirm()
            dismiss()
        }
    }
}

// MARK: - RewardItemRow

struct RewardItemRow: View {
    let reward: RewardItem
    let isRare: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 物品图标
            ZStack {
                Circle()
                    .fill(qualityColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: reward.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(qualityColor)
            }
            .overlay(
                Circle()
                    .stroke(qualityColor.opacity(0.6), lineWidth: isRare ? 2 : 1)
                    .frame(width: 50, height: 50)
            )
            .overlay {
                // 稀有物品发光效果
                if isRare {
                    Circle()
                        .stroke(qualityColor, lineWidth: 2)
                        .frame(width: 50, height: 50)
                        .blur(radius: 4)
                }
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.localizedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.text)

                // 品质条
                QualityBar(quality: reward.quality)
            }

            Spacer()

            // 数量
            Text("×\(reward.quantity)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(qualityColor)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRare ? qualityColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var qualityColor: Color {
        switch reward.quality {
        case 0.9...1.0: return .purple
        case 0.75..<0.9: return .blue
        case 0.6..<0.75: return .green
        default: return .gray
        }
    }
}

// MARK: - QualityBar

struct QualityBar: View {
    let quality: Double

    var body: some View {
        HStack(spacing: 4) {
            // 品质条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))

                    // 填充
                    RoundedRectangle(cornerRadius: 2)
                        .fill(qualityGradient)
                        .frame(width: geometry.size.width * quality)
                }
            }
            .frame(height: 6)

            // 品质百分比
            Text(String(format: "%.0f%%", quality * 100))
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 35, alignment: .trailing)
        }
    }

    private var qualityGradient: LinearGradient {
        let color: Color = {
            switch quality {
            case 0.9...1.0: return .purple
            case 0.75..<0.9: return .blue
            case 0.6..<0.75: return .green
            default: return .gray
            }
        }()

        return LinearGradient(
            colors: [color.opacity(0.7), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Preview

#Preview("With Rewards") {
    ExplorationResultView(
        result: ExplorationResultData(
            sessionId: UUID(),
            duration: 1230,
            distance: 1856,
            poisDiscovered: 3,
            rewards: [
                RewardItem(itemId: "rare_material", quantity: 1, quality: 0.95),
                RewardItem(itemId: "electronics", quantity: 2, quality: 0.88),
                RewardItem(itemId: "metal", quantity: 5, quality: 0.72),
                RewardItem(itemId: "wood", quantity: 8, quality: 0.65),
                RewardItem(itemId: "cloth", quantity: 3, quality: 0.55)
            ]
        ),
        onConfirm: { print("Confirmed") }
    )
}

#Preview("Empty Rewards") {
    ExplorationResultView(
        result: ExplorationResultData(
            sessionId: UUID(),
            duration: 120,
            distance: 150,
            poisDiscovered: 0,
            rewards: []
        ),
        onConfirm: { print("Confirmed") }
    )
}
