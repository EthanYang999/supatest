//
//  StatisticCard.swift
//  supatest
//
//  EarthLord 游戏 - 可复用统计卡片组件
//

import SwiftUI

struct StatisticCard: View {
    // MARK: - 参数

    let icon: String
    let value: String
    let label: String
    var color: Color = ApocalypseTheme.primary

    // MARK: - 动画状态

    @State private var animatedValue: String = ""
    @State private var isAnimating: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            // 图标
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .scaleEffect(isAnimating ? 1.1 : 1.0)

            // 数值
            Text(animatedValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.text)
                .contentTransition(.numericText())

            // 标签
            Text(label)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .onAppear {
            animatedValue = value
        }
        .onChange(of: value) { oldValue, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isAnimating = true
                animatedValue = newValue
            }

            // 重置动画状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    isAnimating = false
                }
            }
        }
    }
}

// MARK: - 便捷初始化器

extension StatisticCard {
    /// 使用数字值初始化
    init(icon: String, numericValue: Int, label: String, color: Color = ApocalypseTheme.primary) {
        self.icon = icon
        self.value = "\(numericValue)"
        self.label = label
        self.color = color
    }

    /// 使用带单位的数字值初始化
    init(icon: String, numericValue: Double, unit: String, label: String, color: Color = ApocalypseTheme.primary) {
        self.icon = icon
        self.value = String(format: "%.1f%@", numericValue, unit)
        self.label = label
        self.color = color
    }
}

// MARK: - 统计卡片行（横向排列多个卡片）

struct StatisticCardRow: View {
    let cards: [StatisticCardData]
    var spacing: CGFloat = 12

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(cards) { card in
                StatisticCard(
                    icon: card.icon,
                    value: card.value,
                    label: card.label,
                    color: card.color
                )
            }
        }
    }
}

// MARK: - 统计卡片数据模型

struct StatisticCardData: Identifiable {
    let id = UUID()
    let icon: String
    let value: String
    let label: String
    var color: Color = ApocalypseTheme.primary

    init(icon: String, value: String, label: String, color: Color = ApocalypseTheme.primary) {
        self.icon = icon
        self.value = value
        self.label = label
        self.color = color
    }

    init(icon: String, numericValue: Int, label: String, color: Color = ApocalypseTheme.primary) {
        self.icon = icon
        self.value = "\(numericValue)"
        self.label = label
        self.color = color
    }
}

// MARK: - 预览

#Preview("单个卡片") {
    VStack(spacing: 20) {
        StatisticCard(
            icon: "flag.fill",
            value: "12",
            label: "领地",
            color: .orange
        )
        .frame(width: 120)

        StatisticCard(
            icon: "shippingbox.fill",
            value: "256",
            label: "物资",
            color: .blue
        )
        .frame(width: 120)

        StatisticCard(
            icon: "figure.walk",
            value: "5.2km",
            label: "行走",
            color: .green
        )
        .frame(width: 120)
    }
    .padding()
    .background(ApocalypseTheme.background)
}

#Preview("卡片行") {
    StatisticCardRow(cards: [
        StatisticCardData(icon: "flag.fill", value: "12", label: "领地", color: .orange),
        StatisticCardData(icon: "shippingbox.fill", value: "256", label: "物资", color: .blue),
        StatisticCardData(icon: "figure.walk", value: "5.2km", label: "行走", color: .green)
    ])
    .padding()
    .background(ApocalypseTheme.background)
}

#Preview("动画效果") {
    StatisticCardAnimationDemo()
}

// MARK: - 动画演示视图

private struct StatisticCardAnimationDemo: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 30) {
            StatisticCard(
                icon: "star.fill",
                value: "\(count)",
                label: "积分",
                color: .yellow
            )
            .frame(width: 120)

            Button("增加数值") {
                count += Int.random(in: 1...10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(ApocalypseTheme.background)
    }
}
