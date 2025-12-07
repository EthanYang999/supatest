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

    /// 显示删除账户第一次确认弹窗
    @State private var showDeleteAccountAlert = false

    /// 显示删除账户第二次确认弹窗（输入 DELETE）
    @State private var showDeleteConfirmSheet = false

    /// 删除确认输入文本
    @State private var deleteConfirmText = ""

    /// 显示删除账户中状态
    @State private var isDeletingAccount = false

    var body: some View {
        ZStack {
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

                            // 删除账户按钮
                            deleteAccountButton

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .navigationTitle("个人")
                .navigationBarTitleDisplayMode(.inline)
            }

            // 全屏加载遮罩
            if isDeletingAccount {
                loadingOverlay
            }
        }
        .alert("确认退出", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("退出登录", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("退出后需要重新登录才能继续游戏")
        }
        .alert("删除账户", isPresented: $showDeleteAccountAlert) {
            Button("取消", role: .cancel) { }
            Button("继续", role: .destructive) {
                showDeleteConfirmSheet = true
            }
        } message: {
            Text("此操作将永久删除您的账户和所有数据，无法恢复。确定要继续吗？")
        }
        .sheet(isPresented: $showDeleteConfirmSheet) {
            deleteConfirmSheet
        }
    }

    // MARK: - 删除确认弹窗

    private var deleteConfirmSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(.top, 40)

                    // 警告文字
                    VStack(spacing: 12) {
                        Text("最终确认")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ApocalypseTheme.text)

                        Text("请输入 DELETE 以确认删除账户")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // 输入框
                    TextField("", text: $deleteConfirmText, prompt: Text("输入 DELETE").foregroundColor(ApocalypseTheme.textSecondary))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(ApocalypseTheme.text)
                        .padding(.horizontal, 24)

                    // 删除按钮
                    Button(action: {
                        showDeleteConfirmSheet = false
                        deleteConfirmText = ""
                        performDeleteAccount()
                    }) {
                        Text("永久删除账户")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(deleteConfirmText == "DELETE" ? ApocalypseTheme.danger : ApocalypseTheme.danger.opacity(0.3))
                            .cornerRadius(12)
                    }
                    .disabled(deleteConfirmText != "DELETE")
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle("删除账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showDeleteConfirmSheet = false
                        deleteConfirmText = ""
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 加载遮罩

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("正在删除账户...")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("请勿关闭应用")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(40)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(20)
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

                // 显示邮箱首字母作为头像
                Text(avatarInitial)
                    .font(.system(size: 42, weight: .bold))
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

    /// 头像首字母
    private var avatarInitial: String {
        if let email = authManager.currentUser?.email, let firstChar = email.first {
            return String(firstChar).uppercased()
        }
        return "?"
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

                settingsRow(icon: "globe", title: "语言设置", showArrow: true) {
                    // TODO: 跳转语言设置
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

    // MARK: - 删除账户按钮

    private var deleteAccountButton: some View {
        Button(action: {
            showDeleteAccountAlert = true
        }) {
            HStack {
                if isDeletingAccount {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.danger))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "trash")
                }
                Text(isDeletingAccount ? "删除中..." : "删除账户")
                    .fontWeight(.medium)
            }
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.danger, lineWidth: 1)
            )
        }
        .disabled(isDeletingAccount || isLoggingOut)
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

    // MARK: - 删除账户方法

    private func performDeleteAccount() {
        isDeletingAccount = true
        Task {
            await authManager.deleteAccount()
            await MainActor.run {
                isDeletingAccount = false
                // 如果删除失败，错误信息会显示在 authManager.errorMessage 中
                // 成功删除后 isAuthenticated 会变为 false，自动跳转到登录页面
            }
        }
    }
}

#Preview {
    ProfileTabView()
}
