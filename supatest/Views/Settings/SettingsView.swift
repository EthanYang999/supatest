//
//  SettingsView.swift
//  supatest
//
//  EarthLord 游戏设置页面
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared

    // MARK: - 状态属性

    /// 显示退出登录确认弹窗
    @State private var showLogoutAlert = false

    /// 显示退出登录中状态
    @State private var isLoggingOut = false

    /// 显示删除账户第一次确认弹窗
    @State private var showDeleteAccountAlert = false

    /// 显示删除账户第二次确认弹窗（输入 DELETE）
    @State private var showDeleteConfirmSheet = false

    /// 删除确认输入文本
    @State private var deleteConfirmText = ""

    /// 显示删除账户中状态
    @State private var isDeletingAccount = false

    // MARK: - 外部链接

    private let privacyPolicyURL = URL(string: "https://coding.aixueai.site/")!
    private let termsOfServiceURL = URL(string: "https://coding.aixueai.site/")!
    private let officialWebsiteURL = URL(string: "https://coding.aixueai.site/")!

    var body: some View {
        ZStack {
            NavigationStack {
                Form {
                    // 通用设置
                    generalSection

                    // 法律与隐私
                    legalSection

                    // 账户操作
                    accountSection
                }
                .scrollContentBackground(.hidden)
                .background(ApocalypseTheme.background)
                .navigationTitle("设置")
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

    // MARK: - 通用设置 Section

    private var generalSection: some View {
        Section {
            NavigationLink {
                LanguageSettingsView()
            } label: {
                settingsRow(
                    icon: "globe",
                    iconColor: ApocalypseTheme.primary,
                    title: "语言",
                    value: localizationManager.currentLanguageDisplayName
                )
            }
        } header: {
            Text("通用设置")
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .listRowBackground(ApocalypseTheme.cardBackground)
    }

    // MARK: - 法律与隐私 Section

    private var legalSection: some View {
        Section {
            Link(destination: privacyPolicyURL) {
                externalLinkRow(icon: "hand.raised.fill", iconColor: .blue, title: "隐私政策")
            }

            Link(destination: termsOfServiceURL) {
                externalLinkRow(icon: "doc.text.fill", iconColor: .green, title: "用户协议")
            }

            Link(destination: officialWebsiteURL) {
                externalLinkRow(icon: "safari.fill", iconColor: .orange, title: "官方网站")
            }
        } header: {
            Text("法律与隐私")
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .listRowBackground(ApocalypseTheme.cardBackground)
    }

    // MARK: - 账户操作 Section

    private var accountSection: some View {
        Section {
            Button(action: { showLogoutAlert = true }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.warning)
                        .frame(width: 28)

                    Text("退出登录")
                        .foregroundColor(ApocalypseTheme.warning)

                    Spacer()

                    if isLoggingOut {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.warning))
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isLoggingOut || isDeletingAccount)

            Button(action: { showDeleteAccountAlert = true }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ApocalypseTheme.danger)
                        .frame(width: 28)

                    Text("删除账户")
                        .foregroundColor(ApocalypseTheme.danger)

                    Spacer()
                }
            }
            .disabled(isLoggingOut || isDeletingAccount)
        } header: {
            Text("账户操作")
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .listRowBackground(ApocalypseTheme.cardBackground)
    }

    // MARK: - 辅助视图

    private func settingsRow(icon: String, iconColor: Color, title: String, value: String? = nil) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 28)

            Text(title)
                .foregroundColor(ApocalypseTheme.text)

            Spacer()

            if let value = value {
                Text(value)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }

    private func externalLinkRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 28)

            Text(title)
                .foregroundColor(ApocalypseTheme.text)

            Spacer()

            Image(systemName: "arrow.up.right.square")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
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
                    TextField(text: $deleteConfirmText, prompt: Text("输入 DELETE").foregroundColor(ApocalypseTheme.textSecondary)) {}
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

    // MARK: - 操作方法

    private func performLogout() {
        isLoggingOut = true
        Task {
            await authManager.signOut()
            await MainActor.run {
                isLoggingOut = false
            }
        }
    }

    private func performDeleteAccount() {
        isDeletingAccount = true
        Task {
            await authManager.deleteAccount()
            await MainActor.run {
                isDeletingAccount = false
            }
        }
    }
}

#Preview {
    SettingsView()
}
