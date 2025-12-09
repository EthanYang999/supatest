//
//  MapTabView.swift
//  supatest
//
//  EarthLord Game - Map Tab with Apocalypse Style
//

import SwiftUI
import CoreLocation
import Auth

// MARK: - CLLocationCoordinate2D Equatable Extension

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - MapTabView

struct MapTabView: View {
    @StateObject private var locationManager = LocationManager()
    @ObservedObject var explorationManager = ExplorationManager.shared
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var discoveryManager = DiscoveryManager.shared

    @State private var userLocation: CLLocationCoordinate2D?
    @State private var shouldCenterOnUser: Bool = true
    @State private var showLocationError: Bool = false

    /// 探索操作加载状态
    @State private var isExplorationLoading: Bool = false

    /// 显示探索结果弹窗
    @State private var showExplorationResult: Bool = false

    /// 探索结果数据
    @State private var explorationResult: ExplorationResult?

    /// 显示错误弹窗
    @State private var showErrorAlert: Bool = false

    /// 错误信息
    @State private var errorMessage: String = ""

    /// 选中的 POI（用于显示详情）
    @State private var selectedPOI: POI?

    /// 显示 POI 详情弹窗
    @State private var showPOIDetail: Bool = false

    #if DEBUG
    /// 显示调试模式提示
    @State private var showDebugToast: Bool = false
    @State private var debugToastMessage: String = ""
    #endif

    var body: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(
                userLocation: $userLocation,
                shouldCenterOnUser: $shouldCenterOnUser,
                nearbyPOIs: explorationManager.nearbyPOIs,
                discoveredPOIIds: explorationManager.discoveredPOIIds,
                onPOITapped: { poi in
                    selectedPOI = poi
                    showPOIDetail = true
                },
                onTripleFingerTap: {
                    #if DEBUG
                    handleDebugSimulation()
                    #endif
                }
            )
            .ignoresSafeArea()

            // 顶部状态栏遮罩
            VStack {
                topGradientOverlay
                Spacer()
            }

            // 探索状态栏（探索中显示）
            if explorationManager.isExploring {
                VStack {
                    explorationStatusBar
                        .padding(.top, 60)
                    Spacer()
                }
            }

            // 控制按钮
            VStack {
                Spacer()

                // 探索按钮
                explorationButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                HStack {
                    Spacer()

                    // 重新定位按钮
                    relocateButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 100)
                }
            }

            // 位置权限提示
            if locationManager.authorizationStatus == .denied ||
               locationManager.authorizationStatus == .restricted {
                locationPermissionOverlay
            }
        }
        .onAppear {
            locationManager.requestAuthorization()
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            userLocation = newLocation
            // 探索中时更新位置统计
            if let location = newLocation {
                explorationManager.updateLocation(location)
            }
        }
        .alert(
            "定位错误",
            isPresented: $showLocationError,
            actions: {
                Button("确定", role: .cancel) {}
            },
            message: {
                Text(locationManager.locationError?.errorDescription ?? "未知错误")
            }
        )
        .alert(
            "探索完成",
            isPresented: $showExplorationResult,
            actions: {
                Button("确定", role: .cancel) {}
            },
            message: {
                if let result = explorationResult {
                    Text("探索时长: \(formatDuration(result.duration))\n移动距离: \(Int(result.totalDistance))米")
                } else {
                    Text("探索已结束")
                }
            }
        )
        .alert(
            "错误",
            isPresented: $showErrorAlert,
            actions: {
                Button("确定", role: .cancel) {}
            },
            message: {
                Text(errorMessage)
            }
        )
        .sheet(isPresented: $showPOIDetail) {
            if let poi = selectedPOI {
                POIDetailSheet(poi: poi)
            }
        }
        .overlay {
            // 发现 POI 弹窗
            if discoveryManager.showDiscoveryAlert, let result = discoveryManager.lastDiscoveryResult {
                DiscoveryAlertView(
                    discoveryResult: result,
                    onExplore: {
                        // 选中该 POI 并显示详情
                        selectedPOI = result.poi
                        showPOIDetail = true
                    },
                    onDismiss: {
                        discoveryManager.dismissDiscoveryAlert()
                    }
                )
                .transition(.opacity)
            }
        }
        .onChange(of: locationManager.locationError) { _, error in
            showLocationError = error != nil
        }
        #if DEBUG
        .overlay(alignment: .top) {
            // Debug 提示 Toast
            if showDebugToast {
                debugToastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 120)
            }
        }
        #endif
    }

    // MARK: - POI Detail Sheet

    private struct POIDetailSheet: View {
        let poi: POI
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                ZStack {
                    ApocalypseTheme.background
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        // POI 图标
                        ZStack {
                            Circle()
                                .fill(Color(poi.poiType.poiColor))
                                .frame(width: 80, height: 80)

                            Image(systemName: poi.poiType.poiIconName)
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)

                        // POI 名称
                        Text(poi.name ?? String(localized: "未知地点"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.text)

                        // POI 类型
                        Text(poi.poiType.localizedDisplayName)
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(20)

                        // 坐标信息
                        VStack(spacing: 8) {
                            HStack {
                                Text("纬度")
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                Spacer()
                                Text(String(format: "%.6f", poi.latitude))
                                    .foregroundColor(ApocalypseTheme.text)
                                    .font(.system(.body, design: .monospaced))
                            }
                            HStack {
                                Text("经度")
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                Spacer()
                                Text(String(format: "%.6f", poi.longitude))
                                    .foregroundColor(ApocalypseTheme.text)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)

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
                .navigationTitle("地点详情")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Top Gradient Overlay

    private var topGradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                ApocalypseTheme.background.opacity(0.8),
                ApocalypseTheme.background.opacity(0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 100)
        .allowsHitTesting(false)
    }

    // MARK: - Relocate Button

    private var relocateButton: some View {
        Button {
            shouldCenterOnUser = true
            locationManager.requestLocation()
        } label: {
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.cardBackground.opacity(0.9))
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                Image(systemName: locationManager.isLocating ? "location.fill" : "location")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(
                        locationManager.isLocating
                            ? ApocalypseTheme.primary
                            : ApocalypseTheme.text
                    )
            }
        }
        .disabled(locationManager.isLocating)
    }

    // MARK: - Location Permission Overlay

    private var locationPermissionOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("需要位置权限")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)

                Text("请在设置中允许访问位置，以便在末日世界中探索")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    openAppSettings()
                } label: {
                    Text("打开设置")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(25)
                }
                .padding(.top, 10)
            }
        }
    }

    // MARK: - Exploration Status Bar

    private var explorationStatusBar: some View {
        HStack(spacing: 12) {
            // 探索中指示器
            Circle()
                .fill(ApocalypseTheme.warning)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(ApocalypseTheme.warning.opacity(0.5), lineWidth: 4)
                        .scaleEffect(1.5)
                )

            Text("探索中...")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.text)

            Spacer()

            // 已发现POI数量
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("\(explorationManager.nearbyPOIs.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.text)
                Text("附近")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 移动距离
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("\(Int(explorationManager.explorationStats.totalDistance))m")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.text)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground.opacity(0.95))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - Exploration Button

    private var explorationButton: some View {
        Button {
            if explorationManager.isExploring {
                stopExploration()
            } else {
                startExploration()
            }
        } label: {
            HStack(spacing: 12) {
                if isExplorationLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: explorationManager.isExploring ? "stop.fill" : "figure.walk")
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(explorationButtonTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(explorationButtonBackground)
            .cornerRadius(12)
            .shadow(color: explorationManager.isExploring ? ApocalypseTheme.warning.opacity(0.4) : ApocalypseTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(isExplorationLoading || userLocation == nil)
        .opacity(userLocation == nil ? 0.5 : 1)
    }

    /// 探索按钮标题
    private var explorationButtonTitle: LocalizedStringKey {
        if isExplorationLoading {
            return explorationManager.isExploring ? "停止中..." : "启动中..."
        }
        return explorationManager.isExploring ? "停止探索" : "开始探索"
    }

    /// 探索按钮背景
    private var explorationButtonBackground: some View {
        Group {
            if explorationManager.isExploring {
                LinearGradient(
                    colors: [ApocalypseTheme.warning, ApocalypseTheme.warning.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                LinearGradient(
                    colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    // MARK: - Exploration Actions

    /// 开始探索
    private func startExploration() {
        guard let location = userLocation else {
            errorMessage = String(localized: "无法获取当前位置")
            showErrorAlert = true
            return
        }

        guard let userId = authManager.currentUser?.id else {
            errorMessage = String(localized: "用户未登录")
            showErrorAlert = true
            return
        }

        isExplorationLoading = true

        Task {
            do {
                try await explorationManager.startExploration(userId: userId, location: location)
                await MainActor.run {
                    isExplorationLoading = false
                }
            } catch {
                await MainActor.run {
                    isExplorationLoading = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    /// 停止探索
    private func stopExploration() {
        guard let location = userLocation else {
            errorMessage = String(localized: "无法获取当前位置")
            showErrorAlert = true
            return
        }

        isExplorationLoading = true

        Task {
            do {
                let result = try await explorationManager.stopExploration(location: location)
                await MainActor.run {
                    isExplorationLoading = false
                    explorationResult = result
                    showExplorationResult = true
                }
            } catch {
                await MainActor.run {
                    isExplorationLoading = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return String(localized: "\(minutes)分\(secs)秒")
        } else {
            return String(localized: "\(secs)秒")
        }
    }

    // MARK: - Debug Methods

    #if DEBUG
    /// Debug Toast 视图
    private var debugToastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "ladybug.fill")
                .foregroundColor(.white)
            Text(debugToastMessage)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.purple.opacity(0.9))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    /// 处理调试模拟发现
    private func handleDebugSimulation() {
        guard explorationManager.isExploring else {
            showDebugToastMessage("请先开始探索")
            return
        }

        guard let userId = authManager.currentUser?.id else {
            showDebugToastMessage("用户未登录")
            return
        }

        Task {
            let success = await discoveryManager.simulateDiscoveryNearest(
                nearbyPOIs: explorationManager.nearbyPOIs,
                discoveredPOIIds: explorationManager.discoveredPOIIds,
                userId: userId
            )

            if success {
                // 更新探索管理器的已发现列表
                if let lastResult = discoveryManager.lastDiscoveryResult {
                    explorationManager.discoveredPOIIds.insert(lastResult.poi.id)
                    explorationManager.poisDiscoveredThisSession += 1
                }
                showDebugToastMessage("模拟发现成功！")
            } else {
                showDebugToastMessage("没有可发现的 POI")
            }
        }
    }

    /// 显示 Debug Toast
    private func showDebugToastMessage(_ message: String) {
        debugToastMessage = message

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showDebugToast = true
        }

        // 2秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showDebugToast = false
            }
        }
    }
    #endif
}

#Preview {
    MapTabView()
}
