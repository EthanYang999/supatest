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

            // 探索状态卡片（探索中显示）
            if explorationManager.isExploring {
                VStack {
                    ExplorationStatusCardCompact(explorationManager: explorationManager)
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
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
        .fullScreenCover(isPresented: $showExplorationResult) {
            if let result = explorationResult {
                ExplorationResultView(
                    result: ExplorationResultData(
                        sessionId: result.sessionId,
                        duration: result.duration,
                        distance: result.totalDistance,
                        poisDiscovered: result.poisDiscovered,
                        rewards: result.rewards
                    ),
                    onConfirm: {
                        explorationResult = nil
                    }
                )
            }
        }
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
            // 批量发现 POI 弹窗（优先显示）
            if discoveryManager.showBatchDiscoveryAlert, !discoveryManager.lastBatchDiscoveryResults.isEmpty {
                BatchDiscoveryAlertView(
                    discoveries: discoveryManager.lastBatchDiscoveryResults,
                    onDismiss: {
                        discoveryManager.dismissBatchDiscoveryAlert()
                    }
                )
                .transition(.opacity)
            }
            // 单个发现 POI 弹窗（保留向后兼容）
            else if discoveryManager.showDiscoveryAlert, let result = discoveryManager.lastDiscoveryResult {
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

    // MARK: - Exploration Button

    private var explorationButton: some View {
        explorationButtonContent
            .onTapGesture {
                if explorationManager.isExploring {
                    stopExploration()
                } else {
                    startExploration()
                }
            }
            #if DEBUG
            .onLongPressGesture(minimumDuration: 2.0) {
                // 长按2秒触发快速测试模式
                startQuickTestExploration()
            }
            #endif
            .disabled(isExplorationLoading || userLocation == nil)
            .opacity(userLocation == nil ? 0.5 : 1)
    }

    private var explorationButtonContent: some View {
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

    /// 快速测试探索（长按触发）
    private func startQuickTestExploration() {
        guard !explorationManager.isExploring else {
            showDebugToastMessage("已在探索中")
            return
        }

        guard let location = userLocation else {
            showDebugToastMessage("无法获取位置")
            return
        }

        guard let userId = authManager.currentUser?.id else {
            showDebugToastMessage("用户未登录")
            return
        }

        showDebugToastMessage("🧪 快速测试开始...")
        isExplorationLoading = true

        Task {
            do {
                let result = try await explorationManager.startQuickTestExploration(
                    userId: userId,
                    location: location,
                    onProgress: { progress in
                        Task { @MainActor in
                            handleQuickTestProgress(progress)
                        }
                    }
                )

                await MainActor.run {
                    isExplorationLoading = false
                    explorationResult = result
                    showExplorationResult = true
                }
            } catch {
                await MainActor.run {
                    isExplorationLoading = false
                    showDebugToastMessage("测试失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 处理快速测试进度
    private func handleQuickTestProgress(_ progress: ExplorationManager.QuickTestProgress) {
        switch progress {
        case .started:
            showDebugToastMessage("🧪 探索已启动")
        case .discoveredPOI(let count):
            showDebugToastMessage("🧪 发现第\(count)个POI")
        case .walking(let distance):
            showDebugToastMessage("🧪 已行走\(Int(distance))米")
        case .finishing:
            showDebugToastMessage("🧪 准备结束...")
        case .completed:
            showDebugToastMessage("🧪 测试完成！")
        case .failed(let error):
            showDebugToastMessage("🧪 失败: \(error.localizedDescription)")
        }
    }
    #endif
}

#Preview {
    MapTabView()
}
