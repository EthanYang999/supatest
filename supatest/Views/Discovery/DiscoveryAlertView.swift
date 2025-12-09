//
//  DiscoveryAlertView.swift
//  supatest
//
//  EarthLord Game - Discovery Alert View
//  显示发现POI的提示弹窗
//

import SwiftUI

// MARK: - DiscoveryAlertView

struct DiscoveryAlertView: View {
    let discoveryResult: DiscoveryResult
    let onExplore: () -> Void
    let onDismiss: () -> Void

    /// 是否显示内容（用于动画）
    @State private var isShowing: Bool = false

    /// 图标脉冲动画
    @State private var isPulsing: Bool = false

    /// 首次发现光晕动画
    @State private var glowOpacity: Double = 0.3

    /// 自动关闭定时器
    @State private var dismissTimer: Timer?

    /// 自动关闭时间（秒）
    private let autoDismissDelay: TimeInterval = 5

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // 弹窗卡片
            VStack(spacing: 0) {
                Spacer()

                cardContent
                    .offset(y: isShowing ? 0 : 300)
                    .opacity(isShowing ? 1 : 0)
            }
        }
        .onAppear {
            startAnimations()
            startDismissTimer()
        }
        .onDisappear {
            dismissTimer?.invalidate()
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: 20) {
            // 顶部发现图标
            discoveryIcon
                .padding(.top, 24)

            // 标题
            Text("发现废墟！")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.text)

            // POI 图标和名称
            poiInfoSection

            // POI 类型标签
            poiTypeTag

            // 首次发现标记
            if discoveryResult.isFirstDiscovery {
                firstDiscoveryBadge
            }

            // 按钮区域
            buttonSection
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: discoveryResult.isFirstDiscovery ? Color.yellow.opacity(0.5) : Color.black.opacity(0.5), radius: 20, x: 0, y: -5)
        )
        .overlay(
            // 首次发现金色边框
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    discoveryResult.isFirstDiscovery
                        ? LinearGradient(colors: [.yellow, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: discoveryResult.isFirstDiscovery ? 2 : 0
                )
                .opacity(glowOpacity)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }

    // MARK: - Discovery Icon

    private var discoveryIcon: some View {
        ZStack {
            // 背景光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            discoveryResult.isFirstDiscovery ? Color.yellow.opacity(0.4) : ApocalypseTheme.primary.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.5 : 0.8)

            // 图标背景
            Circle()
                .fill(
                    LinearGradient(
                        colors: discoveryResult.isFirstDiscovery
                            ? [.yellow, .orange]
                            : [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)

            // 发现图标
            Image(systemName: discoveryResult.isFirstDiscovery ? "star.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.white)
                .scaleEffect(isPulsing ? 1.1 : 1.0)
        }
    }

    // MARK: - POI Info Section

    private var poiInfoSection: some View {
        HStack(spacing: 16) {
            // POI 类型图标
            ZStack {
                Circle()
                    .fill(Color(poiColor))
                    .frame(width: 56, height: 56)

                Image(systemName: poiIconName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            // POI 名称
            VStack(alignment: .leading, spacing: 4) {
                Text(discoveryResult.poi.name ?? String(localized: "未知地点"))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.text)
                    .lineLimit(2)

                Text(poiTypeDisplayName)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - POI Type Tag

    private var poiTypeTag: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(poiColor))

            Text(poiTypeDisplayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(poiColor).opacity(0.2))
        .cornerRadius(20)
    }

    // MARK: - First Discovery Badge

    private var firstDiscoveryBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 16))
                .foregroundColor(.yellow)

            Text("全服首次发现！")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.yellow.opacity(glowOpacity), lineWidth: 1)
        )
    }

    // MARK: - Button Section

    private var buttonSection: some View {
        HStack(spacing: 12) {
            // 关闭按钮
            Button {
                dismiss()
            } label: {
                Text("关闭")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
            }

            // 前往探索按钮
            Button {
                dismiss()
                onExplore()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                    Text("前往探索")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
    }

    // MARK: - POI Type Properties

    private var poiIconName: String {
        switch discoveryResult.poi.poiType {
        case "hospital": return "cross.circle.fill"
        case "supermarket": return "cart.fill"
        case "factory": return "building.2.fill"
        case "gas_station": return "fuelpump.fill"
        case "pharmacy": return "pills.fill"
        case "school": return "book.fill"
        case "police_station": return "shield.fill"
        case "residential": return "house.fill"
        case "park": return "leaf.fill"
        case "restaurant": return "fork.knife"
        default: return "mappin.circle.fill"
        }
    }

    private var poiColor: UIColor {
        switch discoveryResult.poi.poiType {
        case "hospital": return .systemRed
        case "supermarket": return .systemBlue
        case "factory": return .systemGray
        case "gas_station": return .systemYellow
        case "pharmacy": return .systemGreen
        case "school": return .systemIndigo
        case "police_station": return .systemPurple
        case "residential": return .systemBrown
        case "park": return .systemMint
        case "restaurant": return .systemOrange
        default: return .systemTeal
        }
    }

    private var poiTypeDisplayName: LocalizedStringKey {
        switch discoveryResult.poi.poiType {
        case "hospital": return "医院"
        case "supermarket": return "超市"
        case "factory": return "工厂"
        case "gas_station": return "加油站"
        case "pharmacy": return "药房"
        case "school": return "学校"
        case "police_station": return "警察局"
        case "residential": return "住宅区"
        case "park": return "公园"
        case "restaurant": return "餐厅"
        default: return "未知地点"
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // 滑入动画
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isShowing = true
        }

        // 脉冲动画
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            isPulsing = true
        }

        // 光晕动画（首次发现）
        if discoveryResult.isFirstDiscovery {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.8
            }
        }
    }

    private func startDismissTimer() {
        dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissDelay, repeats: false) { _ in
            dismiss()
        }
    }

    private func dismiss() {
        dismissTimer?.invalidate()

        withAnimation(.easeInOut(duration: 0.3)) {
            isShowing = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview("Normal Discovery") {
    DiscoveryAlertView(
        discoveryResult: DiscoveryResult(
            poi: POI(
                id: "test-1",
                poiType: "hospital",
                name: "废弃医院",
                latitude: 23.200,
                longitude: 114.441,
                hasBeenDiscovered: false,
                hasLoot: true
            ),
            isFirstDiscovery: false,
            timestamp: Date()
        ),
        onExplore: { print("Explore tapped") },
        onDismiss: { print("Dismissed") }
    )
}

#Preview("First Discovery") {
    DiscoveryAlertView(
        discoveryResult: DiscoveryResult(
            poi: POI(
                id: "test-2",
                poiType: "supermarket",
                name: "末日超市",
                latitude: 23.200,
                longitude: 114.441,
                hasBeenDiscovered: false,
                hasLoot: true
            ),
            isFirstDiscovery: true,
            timestamp: Date()
        ),
        onExplore: { print("Explore tapped") },
        onDismiss: { print("Dismissed") }
    )
}
