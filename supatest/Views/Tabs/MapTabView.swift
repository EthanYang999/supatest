//
//  MapTabView.swift
//  supatest
//
//  EarthLord Game - 地图主视图
//  显示末世风格卫星地图，集成 GPS 定位功能
//

import SwiftUI
import CoreLocation
import Supabase
import UIKit

// MARK: - MapTabView

struct MapTabView: View {

    // MARK: - Properties

    /// 定位管理器
    @StateObject private var locationManager = LocationManager()

    /// 领地管理器 (Day 18-B3)
    @StateObject private var territoryManager = TerritoryManager.shared

    /// 是否已定位到用户位置
    @State private var hasLocatedUser = false

    /// 追踪开始时间
    @State private var trackingStartTime: Date?

    /// 是否正在上传
    @State private var isUploading = false

    /// 上传结果消息
    @State private var uploadMessage: String?

    /// 是否显示上传结果
    @State private var showUploadResult = false

    /// 当前用户 ID (Day 18-B3)
    @State private var currentUserId: String?

    // MARK: - Day 19: 碰撞检测状态

    /// 碰撞检测定时器
    @State private var collisionCheckTimer: Timer?

    /// 碰撞警告消息
    @State private var collisionWarning: String?

    /// 是否显示碰撞警告
    @State private var showCollisionWarning = false

    /// 当前警告级别
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - Body

    var body: some View {
        ZStack {
            // 末世风格地图（全屏显示）
            MapViewRepresentable(
                userLocation: $locationManager.userLocation,
                hasLocatedUser: $hasLocatedUser,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed,
                territories: territoryManager.territories,
                currentUserId: currentUserId
            )
            .ignoresSafeArea()

            // 顶部渐变遮罩（让状态栏更易读）
            VStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        ApocalypseTheme.background.opacity(0.8),
                        ApocalypseTheme.background.opacity(0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)

                Spacer()
            }
            .ignoresSafeArea()

            // 定位权限被拒绝时显示提示
            if locationManager.isDenied {
                locationDeniedOverlay
            }

            // Day 16: 速度警告横幅
            if locationManager.speedWarning != nil {
                speedWarningBanner
            }

            // Day 17: 验证状态横幅
            if locationManager.isPathClosed {
                validationStatusBanner
            }

            // Day 18: 上传结果提示
            if showUploadResult, let message = uploadMessage {
                uploadResultBanner(message: message)
            }

            // Day 19: 碰撞警告横幅（分级颜色）
            if showCollisionWarning, let warning = collisionWarning {
                collisionWarningBanner(message: warning, level: collisionWarningLevel)
            }

            // 右下角按钮组
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 定位按钮
                        locateButton

                        // Day 18: 验证通过时显示「确认登记」按钮
                        if locationManager.territoryValidationPassed && !isUploading {
                            confirmTerritoryButton
                        }

                        // 圈地按钮 (Day 15)
                        territoryButton
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            // 视图出现时请求定位权限
            locationManager.requestPermission()

            // Day 18-B3: 加载领地和用户 ID
            Task {
                await loadTerritoriesAndUserId()
            }
        }
    }

    // MARK: - Subviews

    /// 定位按钮
    private var locateButton: some View {
        Button(action: {
            // 重新定位到用户位置
            hasLocatedUser = false
            locationManager.startUpdatingLocation()
        }) {
            Image(systemName: locationManager.isAuthorized ? "location.fill" : "location.slash.fill")
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.text)
                .frame(width: 44, height: 44)
                .background(ApocalypseTheme.cardBackground.opacity(0.9))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }

    /// 圈地按钮 (Day 15)
    /// 胶囊型按钮，显示文字和当前路径点数
    private var territoryButton: some View {
        Button(action: {
            if locationManager.isTracking {
                // 停止追踪
                stopCollisionMonitoring()
                locationManager.stopPathTracking()
            } else {
                // Day 19: 开始圈地前检测起始点
                startClaimingWithCollisionCheck()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text(locationManager.isTracking ? "停止圈地" : "开始圈地")
                        .font(.system(size: 14, weight: .medium))

                    // 追踪时显示点数
                    if locationManager.isTracking {
                        Text("\(locationManager.pathCoordinates.count) 点")
                            .font(.system(size: 11))
                            .opacity(0.8)
                    }
                }
            }
            .foregroundColor(locationManager.isTracking ? .white : ApocalypseTheme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(locationManager.isTracking
                ? Color.red.opacity(0.9)
                : ApocalypseTheme.cardBackground.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }

    /// Day 16: 速度警告横幅
    private var speedWarningBanner: some View {
        VStack {
            HStack {
                Image(systemName: locationManager.isOverSpeed ? "exclamationmark.triangle.fill" : "speedometer")
                    .font(.system(size: 18))

                Text(locationManager.speedWarning ?? "")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                // 超速暂停用红色，警告用黄色
                locationManager.isTracking
                    ? Color.orange.opacity(0.95)
                    : Color.red.opacity(0.95)
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 60)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: locationManager.speedWarning)
        .onAppear {
            // 3秒后自动清除警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if locationManager.isTracking {
                    // 仍在追踪，清除警告
                    locationManager.speedWarning = nil
                    locationManager.isOverSpeed = false
                }
            }
        }
    }

    /// 定位权限被拒绝提示
    private var locationDeniedOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.warning)

                Text("无法获取位置")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)

                Text("请在系统设置中开启定位权限\n以便在末日世界中导航")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.secondaryText)
                    .multilineTextAlignment(.center)

                Button(action: openSettings) {
                    Text("前往设置")
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.background)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(25)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(ApocalypseTheme.cardBackground.opacity(0.95))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 150)
        }
    }

    // MARK: - Day 18 Subviews

    /// Day 18: 确认登记领地按钮
    private var confirmTerritoryButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                }

                Text(isUploading ? "上传中..." : "确认登记")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.green.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(isUploading)
    }

    /// Day 17: 验证状态横幅
    private var validationStatusBanner: some View {
        VStack {
            Spacer()

            HStack {
                Image(systemName: locationManager.territoryValidationPassed
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill")
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text(locationManager.territoryValidationPassed
                        ? "验证通过"
                        : "验证失败")
                        .font(.system(size: 14, weight: .medium))

                    if locationManager.territoryValidationPassed {
                        Text("面积: \(Int(locationManager.calculatedArea))m²")
                            .font(.system(size: 12))
                            .opacity(0.8)
                    } else if let error = locationManager.territoryValidationError {
                        Text(error)
                            .font(.system(size: 12))
                            .opacity(0.8)
                    }
                }

                Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                locationManager.territoryValidationPassed
                    ? Color.green.opacity(0.95)
                    : Color.red.opacity(0.95)
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 180)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: locationManager.isPathClosed)
    }

    /// Day 18: 上传结果横幅
    private func uploadResultBanner(message: String) -> some View {
        VStack {
            HStack {
                Image(systemName: message.contains("成功") ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                message.contains("成功")
                    ? Color.green.opacity(0.95)
                    : Color.red.opacity(0.95)
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 60)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showUploadResult)
    }

    // MARK: - Methods

    /// 打开系统设置
    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    /// Day 18: 上传当前领地
    private func uploadCurrentTerritory() async {
        // 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            showUploadMessage("领地验证未通过，无法上传", isSuccess: false)
            return
        }

        isUploading = true

        do {
            try await TerritoryManager.shared.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: trackingStartTime ?? Date()
            )

            // 上传成功
            showUploadMessage("领地登记成功！", isSuccess: true)

            // Day 19: 停止碰撞监控
            stopCollisionMonitoring()

            // 停止追踪（会重置所有状态，防止重复上传）
            locationManager.stopPathTracking()
            trackingStartTime = nil

            // Day 18-B3: 刷新领地列表
            _ = try? await territoryManager.loadAllTerritories()

        } catch {
            showUploadMessage("上传失败: \(error.localizedDescription)", isSuccess: false)
        }

        isUploading = false
    }

    /// 显示上传结果消息
    private func showUploadMessage(_ message: String, isSuccess: Bool) {
        uploadMessage = message
        showUploadResult = true

        // 3秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showUploadResult = false
            uploadMessage = nil
        }
    }

    /// Day 18-B3: 加载领地和用户 ID
    private func loadTerritoriesAndUserId() async {
        // 获取当前用户 ID
        if let userId = try? await supabase.auth.session.user.id {
            currentUserId = userId.uuidString
        }

        // 加载所有领地
        _ = try? await territoryManager.loadAllTerritories()
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            return
        }

        // 检测起始点是否在他人领地内
        let result = territoryManager.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            // 起点在他人领地内，显示错误并震动
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            // 3秒后隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }

            return
        }

        // 起点安全，开始圈地
        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        trackingStartTime = Date()
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = territoryManager.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        // 根据预警级别处理
        switch result.warningLevel {
        case .safe:
            // 安全，隐藏警告横幅
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            // 注意（50-100m）- 黄色横幅 + 轻震 1 次
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            // 警告（25-50m）- 橙色横幅 + 中震 2 次
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            // 危险（<25m）- 红色横幅 + 强震 3 次
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 【关键修复】违规处理 - 必须先显示横幅，再停止！

            // 1. 先设置警告状态（让横幅显示出来）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 触发震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除警告状态！
            stopCollisionCheckTimer()

            // 4. 停止圈地追踪
            locationManager.stopPathTracking()
            trackingStartTime = nil

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5秒后再清除警告横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 120)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
    }
}

// MARK: - Preview

#Preview {
    MapTabView()
}
