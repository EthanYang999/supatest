//
//  BatchDiscoveryAlertView.swift
//  supatest
//
//  EarthLord Game - Batch Discovery Alert View
//  批量发现POI的提示弹窗
//

import SwiftUI

// MARK: - BatchDiscoveryAlertView

struct BatchDiscoveryAlertView: View {
    let discoveries: [DiscoveryResult]
    let onDismiss: () -> Void

    /// 是否显示内容（用于动画）
    @State private var isShowing: Bool = false

    /// 图标脉冲动画
    @State private var isPulsing: Bool = false

    /// 已显示的物品索引
    @State private var visibleItemIndices: Set<Int> = []

    /// 自动关闭定时器
    @State private var dismissTimer: Timer?

    /// 自动关闭时间（秒）- 根据发现数量动态调整
    private var autoDismissDelay: TimeInterval {
        min(10, Double(5 + discoveries.count))
    }

    /// 是否有首次发现
    private var hasFirstDiscovery: Bool {
        discoveries.contains { $0.isFirstDiscovery }
    }

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
        VStack(spacing: 16) {
            // 拖动指示条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            // 顶部发现图标
            discoveryIcon

            // 标题
            VStack(spacing: 4) {
                Text("发现废墟！")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)

                Text("发现 \(discoveries.count) 个地点")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // POI 列表
            poiList
                .frame(maxHeight: 280)

            // 首次发现标记
            if hasFirstDiscovery {
                firstDiscoveryBadge
            }

            // 按钮区域
            confirmButton
                .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: hasFirstDiscovery ? Color.yellow.opacity(0.5) : Color.black.opacity(0.5), radius: 20, x: 0, y: -5)
        )
        .overlay(
            // 首次发现金色边框
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    hasFirstDiscovery
                        ? LinearGradient(colors: [.yellow, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: hasFirstDiscovery ? 2 : 0
                )
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
                            hasFirstDiscovery ? Color.yellow.opacity(0.4) : ApocalypseTheme.primary.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 100, height: 100)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.5 : 0.8)

            // 图标背景
            Circle()
                .fill(
                    LinearGradient(
                        colors: hasFirstDiscovery
                            ? [.yellow, .orange]
                            : [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)

            // 数量显示
            VStack(spacing: 0) {
                Text("\(discoveries.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("发现")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - POI List

    private var poiList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(Array(discoveries.enumerated()), id: \.element.poi.id) { index, discovery in
                    POIListItem(discovery: discovery)
                        .opacity(visibleItemIndices.contains(index) ? 1 : 0)
                        .offset(x: visibleItemIndices.contains(index) ? 0 : -20)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    // MARK: - First Discovery Badge

    private var firstDiscoveryBadge: some View {
        let firstDiscoveryCount = discoveries.filter { $0.isFirstDiscovery }.count

        return HStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 14))
                .foregroundColor(.yellow)

            Text("包含 \(firstDiscoveryCount) 个全服首次发现！")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                Text("知道了")
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

        // 物品列表依次淡入
        for index in 0..<discoveries.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(index) * 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    _ = visibleItemIndices.insert(index)
                }
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

// MARK: - POIListItem

private struct POIListItem: View {
    let discovery: DiscoveryResult

    var body: some View {
        HStack(spacing: 12) {
            // POI 类型图标
            ZStack {
                Circle()
                    .fill(Color(poiColor))
                    .frame(width: 40, height: 40)

                Image(systemName: poiIconName)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }

            // POI 名称和类型
            VStack(alignment: .leading, spacing: 2) {
                Text(discovery.poi.name ?? String(localized: "未知地点"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.text)
                    .lineLimit(1)

                Text(poiTypeDisplayName)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 首次发现标记
            if discovery.isFirstDiscovery {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                    Text("首发")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.yellow)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal, 8)
    }

    // MARK: - POI Type Properties

    private var poiIconName: String {
        switch discovery.poi.poiType {
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
        switch discovery.poi.poiType {
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
        switch discovery.poi.poiType {
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
}

// MARK: - Preview

#Preview("Batch Discovery - 3 POIs") {
    BatchDiscoveryAlertView(
        discoveries: [
            DiscoveryResult(
                poi: POI(
                    id: "test-1",
                    poiType: "hospital",
                    name: "废弃医院",
                    latitude: 23.200,
                    longitude: 114.441,
                    hasBeenDiscovered: false,
                    hasLoot: true
                ),
                isFirstDiscovery: true,
                timestamp: Date()
            ),
            DiscoveryResult(
                poi: POI(
                    id: "test-2",
                    poiType: "supermarket",
                    name: "末日超市",
                    latitude: 23.201,
                    longitude: 114.442,
                    hasBeenDiscovered: false,
                    hasLoot: true
                ),
                isFirstDiscovery: false,
                timestamp: Date()
            ),
            DiscoveryResult(
                poi: POI(
                    id: "test-3",
                    poiType: "gas_station",
                    name: "废弃加油站",
                    latitude: 23.202,
                    longitude: 114.443,
                    hasBeenDiscovered: false,
                    hasLoot: true
                ),
                isFirstDiscovery: false,
                timestamp: Date()
            )
        ],
        onDismiss: { print("Dismissed") }
    )
}

#Preview("Batch Discovery - 6 POIs") {
    BatchDiscoveryAlertView(
        discoveries: [
            DiscoveryResult(
                poi: POI(id: "1", poiType: "hospital", name: "废弃医院", latitude: 23.200, longitude: 114.441, hasBeenDiscovered: false, hasLoot: true),
                isFirstDiscovery: true,
                timestamp: Date()
            ),
            DiscoveryResult(
                poi: POI(id: "2", poiType: "supermarket", name: "末日超市", latitude: 23.201, longitude: 114.442, hasBeenDiscovered: false, hasLoot: true),
                isFirstDiscovery: false,
                timestamp: Date()
            ),
            DiscoveryResult(
                poi: POI(id: "3", poiType: "gas_station", name: "废弃加油站", latitude: 23.202, longitude: 114.443, hasBeenDiscovered: false, hasLoot: true),
                isFirstDiscovery: true,
                timestamp: Date()
            ),
            DiscoveryResult(
                poi: POI(id: "4", poiType: "pharmacy", name: "药房", latitude: 23.203, longitude: 114.444, hasBeenDiscovered: false, hasLoot: true),
                isFirstDiscovery: false,
                timestamp: Date()
            ),
            DiscoveryResult(
                poi: POI(id: "5", poiType: "school", name: "废弃学校", latitude: 23.204, longitude: 114.445, hasBeenDiscovered: false, hasLoot: true),
                isFirstDiscovery: false,
                timestamp: Date()
            ),
            DiscoveryResult(
                poi: POI(id: "6", poiType: "restaurant", name: "废弃餐厅", latitude: 23.205, longitude: 114.446, hasBeenDiscovered: false, hasLoot: true),
                isFirstDiscovery: false,
                timestamp: Date()
            )
        ],
        onDismiss: { print("Dismissed") }
    )
}
