//
//  ProfileTabView.swift
//  supatest
//
//  EarthLord Game - Profile Tab
//  显示用户信息和设置选项
//

import SwiftUI
import Supabase

struct ProfileTabView: View {
    @ObservedObject var authManager = AuthManager.shared

    /// 显示登出确认弹窗
    @State private var showLogoutAlert = false

    /// 显示登出中状态
    @State private var isLoggingOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 用户信息卡片
                        userInfoCard
                            .padding(.top, 20)

                        // 统计数据
                        statsSection

                        // 设置选项
                        settingsSection

                        // 退出登录按钮
                        logoutButton
                            .padding(.top, 20)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("个人")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("确认退出", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("退出登录", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("退出后需要重新登录才能继续游戏")
        }
    }

    // MARK: - 用户信息卡片

    private var userInfoCard: some View {
        VStack(spacing: 16) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                // 如果有头像URL则显示头像，否则显示默认图标
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // 用户名
            VStack(spacing: 4) {
                Text(displayUsername)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)

                // 用户邮箱
                if let email = authManager.currentUser?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 用户ID（简短显示）
                if let userId = authManager.currentUser?.id {
                    Text("ID: \(String(userId.uuidString.prefix(8)))...")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    /// 显示用户名
    private var displayUsername: String {
        if let email = authManager.currentUser?.email {
            // 从邮箱提取用户名部分
            return email.components(separatedBy: "@").first ?? "幸存者"
        }
        return "幸存者"
    }

    // MARK: - 统计数据

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("幸存者档案")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.text)

            HStack(spacing: 12) {
                statCard(icon: "flag.fill", title: "领地", value: "0")
                statCard(icon: "shippingbox.fill", title: "物资", value: "0")
                statCard(icon: "figure.walk", title: "行走", value: "0km")
            }
        }
    }

    private func statCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.text)

            Text(title)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 设置选项

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.text)

            VStack(spacing: 0) {
                settingsRow(icon: "person.circle", title: "编辑资料", showArrow: true) {
                    // TODO: 跳转编辑资料页面
                }

                Divider()
                    .background(ApocalypseTheme.separator)

                settingsRow(icon: "bell", title: "通知设置", showArrow: true) {
                    // TODO: 跳转通知设置
                }

                Divider()
                    .background(ApocalypseTheme.separator)

                settingsRow(icon: "questionmark.circle", title: "帮助与反馈", showArrow: true) {
                    // TODO: 跳转帮助页面
                }

                Divider()
                    .background(ApocalypseTheme.separator)

                settingsRow(icon: "info.circle", title: "关于", showArrow: true) {
                    // TODO: 跳转关于页面
                }
            }
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    private func settingsRow(icon: String, title: String, showArrow: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 28)

                Text(title)
                    .foregroundColor(ApocalypseTheme.text)

                Spacer()

                if showArrow {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - 退出登录按钮

    private var logoutButton: some View {
        Button(action: {
            showLogoutAlert = true
        }) {
            HStack {
                if isLoggingOut {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                Text(isLoggingOut ? "退出中..." : "退出登录")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(ApocalypseTheme.danger)
            .cornerRadius(12)
        }
        .disabled(isLoggingOut)
    }

    // MARK: - 登出方法

    private func performLogout() {
        isLoggingOut = true
        Task {
            await authManager.signOut()
            await MainActor.run {
                isLoggingOut = false
            }
        }
    }
}

#Preview {
    ProfileTabView()
}
