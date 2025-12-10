//
//  TerritoryTestView.swift
//  supatest
//
//  EarthLord Game - 圈地测试界面
//  显示圈地模块的调试日志，支持清空和导出
//
//  ⚠️ 注意：此视图不套 NavigationStack，因为它是从 TestMenuView 导航进来的
//

import SwiftUI
import CoreLocation

// MARK: - TerritoryTestView

/// 圈地测试界面
struct TerritoryTestView: View {

    // MARK: - Properties

    /// 定位管理器（通过 EnvironmentObject 注入）
    @EnvironmentObject var locationManager: LocationManager

    /// 日志管理器
    @ObservedObject var logger = TerritoryLogger.shared

    /// 领地管理器
    @ObservedObject var territoryManager = TerritoryManager.shared

    /// 测试上传状态
    @State private var isUploading = false

    /// 上传结果消息
    @State private var uploadMessage: String?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding()
                .background(ApocalypseTheme.cardBackground)

            Divider()

            // 日志区域
            logScrollView

            Divider()

            // 底部按钮栏
            bottomBar
                .padding()
                .background(ApocalypseTheme.cardBackground)
        }
        .navigationTitle("圈地测试")
        .navigationBarTitleDisplayMode(.inline)
        .background(ApocalypseTheme.background)
    }

    // MARK: - Subviews

    /// 状态指示器
    private var statusIndicator: some View {
        HStack {
            // 追踪状态
            HStack(spacing: 8) {
                Circle()
                    .fill(locationManager.isTracking ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                Text(locationManager.isTracking ? "追踪中" : "未追踪")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.text)
            }

            Spacer()

            // 路径点数
            if locationManager.isTracking {
                Text("\(locationManager.pathCoordinates.count) 点")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }

            // 闭环状态
            if locationManager.isPathClosed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已闭环")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
    }

    /// 日志滚动区域
    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if logger.logText.isEmpty {
                        Text("暂无日志，开始圈地追踪后将显示日志")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.secondaryText)
                            .padding()
                    } else {
                        Text(logger.logText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .id("logBottom")
                    }
                }
            }
            .background(ApocalypseTheme.background)
            .onChange(of: logger.logText) { _, _ in
                // 日志更新时自动滚动到底部
                withAnimation {
                    proxy.scrollTo("logBottom", anchor: .bottom)
                }
            }
        }
    }

    /// 底部按钮栏
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // 上传结果消息
            if let message = uploadMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(message.contains("成功") ? .green : .red)
                    .padding(.horizontal)
            }

            HStack(spacing: 16) {
                // 测试上传按钮
                Button(action: {
                    testUpload()
                }) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle")
                        }
                        Text(isUploading ? "上传中..." : "测试上传")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isUploading ? Color.gray : Color.blue)
                    .cornerRadius(8)
                }
                .disabled(isUploading)

                // 清空日志按钮
                Button(action: {
                    logger.clear()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("清空")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                }

                // 导出日志按钮
                ShareLink(item: logger.export()) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Methods

    /// 测试上传领地
    private func testUpload() {
        isUploading = true
        uploadMessage = nil

        Task {
            // 创建测试坐标（一个小三角形）
            let testCoords = [
                CLLocationCoordinate2D(latitude: 23.1, longitude: 113.3),
                CLLocationCoordinate2D(latitude: 23.1, longitude: 113.31),
                CLLocationCoordinate2D(latitude: 23.11, longitude: 113.305),
                CLLocationCoordinate2D(latitude: 23.1, longitude: 113.3)  // 闭合
            ]

            do {
                try await territoryManager.uploadTerritory(
                    coordinates: testCoords,
                    area: 100.0,
                    startTime: Date()
                )
                print("✅ 测试上传成功")
                uploadMessage = "✅ 测试上传成功"
            } catch {
                print("❌ 测试上传失败: \(error)")
                uploadMessage = "❌ 上传失败: \(error.localizedDescription)"
            }

            isUploading = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager())
    }
}
