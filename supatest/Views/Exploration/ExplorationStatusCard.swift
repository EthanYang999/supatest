//
//  ExplorationStatusCard.swift
//  supatest
//
//  EarthLord Game - Exploration Status Card
//  探索中实时状态悬浮卡片
//

import SwiftUI
import Combine

// MARK: - ExplorationStatusCard

struct ExplorationStatusCard: View {
    @ObservedObject var explorationManager: ExplorationManager

    /// 计时器用于实时更新时间显示
    @State private var timer: Timer?

    /// 当前显示的探索时长（秒）
    @State private var elapsedSeconds: Int = 0

    /// 脉冲动画状态
    @State private var isPulsing: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // 探索中指示器
            exploringIndicator

            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 30)

            // 时间
            statItem(
                icon: "clock.fill",
                value: formattedTime,
                label: "时间"
            )

            // 距离
            statItem(
                icon: "figure.walk",
                value: formattedDistance,
                label: "距离"
            )

            // 发现数
            statItem(
                icon: "building.2.fill",
                value: "\(explorationManager.poisDiscoveredThisSession)",
                label: "发现"
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            startTimer()
            startPulseAnimation()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: explorationManager.isExploring) { _, isExploring in
            if isExploring {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    // MARK: - Exploring Indicator

    private var exploringIndicator: some View {
        ZStack {
            // 外层脉冲圆
            Circle()
                .fill(ApocalypseTheme.warning.opacity(0.3))
                .frame(width: 36, height: 36)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0.0 : 0.5)

            // 内层实心圆
            Circle()
                .fill(ApocalypseTheme.warning)
                .frame(width: 28, height: 28)

            // 图标
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Stat Item

    private func statItem(icon: String, value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.warning)

                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.text)
            }

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - Formatted Values

    /// 格式化时间显示
    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 格式化距离显示
    private var formattedDistance: String {
        let distance = explorationManager.explorationStats.totalDistance
        if distance >= 1000 {
            return String(format: "%.1fkm", distance / 1000)
        } else {
            return String(format: "%.0fm", distance)
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        stopTimer() // 确保没有重复的定时器

        // 计算初始已过时间
        if let startTime = explorationManager.explorationStats.startTime {
            elapsedSeconds = Int(Date().timeIntervalSince(startTime))
        } else {
            elapsedSeconds = 0
        }

        // 创建每秒更新的定时器
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = explorationManager.explorationStats.startTime {
                elapsedSeconds = Int(Date().timeIntervalSince(startTime))
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Pulse Animation

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
    }
}

// MARK: - Compact Version

/// 紧凑版本的探索状态卡片（仅显示关键信息）
struct ExplorationStatusCardCompact: View {
    @ObservedObject var explorationManager: ExplorationManager

    /// 计时器
    @State private var timer: Timer?
    @State private var elapsedSeconds: Int = 0
    @State private var isPulsing: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 脉冲指示器
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.warning.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.6)

                Circle()
                    .fill(ApocalypseTheme.warning)
                    .frame(width: 16, height: 16)
            }

            // 探索中文字
            Text("探索中")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.text)

            Spacer()

            // 时间
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.warning)
                Text(formattedTime)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.text)
            }

            // 距离
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.warning)
                Text(formattedDistance)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.text)
            }

            // 发现数
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.warning)
                Text("\(explorationManager.poisDiscoveredThisSession)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.text)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground.opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.warning.opacity(0.4), lineWidth: 1)
        )
        .onAppear {
            startTimer()
            startPulseAnimation()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: explorationManager.isExploring) { _, isExploring in
            if isExploring {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var formattedDistance: String {
        let distance = explorationManager.explorationStats.totalDistance
        if distance >= 1000 {
            return String(format: "%.1fkm", distance / 1000)
        } else {
            return String(format: "%.0fm", distance)
        }
    }

    private func startTimer() {
        timer?.invalidate()

        if let startTime = explorationManager.explorationStats.startTime {
            elapsedSeconds = Int(Date().timeIntervalSince(startTime))
        } else {
            elapsedSeconds = 0
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = explorationManager.explorationStats.startTime {
                elapsedSeconds = Int(Date().timeIntervalSince(startTime))
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
    }
}

// MARK: - Preview

#Preview("Status Card") {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack {
            ExplorationStatusCard(explorationManager: ExplorationManager.shared)
                .padding()

            Spacer()
        }
    }
}

#Preview("Compact Card") {
    ZStack {
        ApocalypseTheme.background
            .ignoresSafeArea()

        VStack {
            ExplorationStatusCardCompact(explorationManager: ExplorationManager.shared)
                .padding()

            Spacer()
        }
    }
}
