//
//  MapTabView.swift
//  supatest
//
//  EarthLord Game - 地图主视图
//  显示末世风格卫星地图，集成 GPS 定位功能
//

import SwiftUI
import CoreLocation

// MARK: - MapTabView

struct MapTabView: View {

    // MARK: - Properties

    /// 定位管理器
    @StateObject private var locationManager = LocationManager()

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
                isPathClosed: locationManager.isPathClosed
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
                locationManager.stopPathTracking()
            } else {
                // 开始追踪，记录开始时间
                trackingStartTime = Date()
                locationManager.startPathTracking()
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

            // 停止追踪（会重置所有状态，防止重复上传）
            locationManager.stopPathTracking()
            trackingStartTime = nil

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
}

// MARK: - Preview

#Preview {
    MapTabView()
}
