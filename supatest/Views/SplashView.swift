//
//  SplashView.swift
//  supatest
//
//  EarthLord 游戏启动画面
//  显示 Logo、标题和加载动画，同时检查用户会话状态
//

import SwiftUI

struct SplashView: View {
    @ObservedObject var authManager: AuthManager

    /// 是否显示加载动画
    @State private var isAnimating = false

    /// 加载进度文字
    @State private var loadingText = "正在连接服务器..."

    /// Logo 缩放动画
    @State private var logoScale: CGFloat = 0.8

    /// Logo 透明度
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "1A1A2E"),
                    Color(hex: "16213E"),
                    Color(hex: "0F0F1A")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Logo
                ZStack {
                    // 外圈光晕
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ApocalypseTheme.primary.opacity(0.3),
                                    ApocalypseTheme.primary.opacity(0)
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                    // Logo 圆形背景
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primary.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

                    // 地球图标
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // 标题
                VStack(spacing: 8) {
                    Text("地球新主")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(ApocalypseTheme.text)

                    Text("EARTH LORD")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .tracking(4)
                }
                .opacity(logoOpacity)

                Spacer()

                // 加载指示器
                VStack(spacing: 16) {
                    // 自定义加载动画
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(ApocalypseTheme.primary)
                                .frame(width: 10, height: 10)
                                .scaleEffect(isAnimating ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }

                    // 加载文字
                    Text(loadingText)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
            checkSession()
        }
    }

    // MARK: - 动画方法

    private func startAnimations() {
        // Logo 入场动画
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // 启动循环动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = true
        }
    }

    // MARK: - 检查会话

    private func checkSession() {
        Task {
            // 更新加载文字
            await MainActor.run {
                loadingText = "正在检查登录状态..."
            }

            // 检查会话
            await authManager.checkSession()

            // 短暂延迟确保动画流畅
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            await MainActor.run {
                if authManager.isAuthenticated {
                    loadingText = "欢迎回来，幸存者"
                } else {
                    loadingText = "准备就绪"
                }
            }
        }
    }
}

#Preview {
    SplashView(authManager: AuthManager.shared)
}
