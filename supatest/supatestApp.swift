//
//  supatestApp.swift
//  supatest
//
//  Created by Ethan on 12/5/25.
//

import SwiftUI

@main
struct supatestApp: App {
    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 语言管理器
    @StateObject private var localizationManager = LocalizationManager.shared

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(localizationManager)
                // 使用 refreshID 强制刷新整个 UI 树
                .id(localizationManager.refreshID)
        }
    }

    private func configureAppearance() {
        // Configure TabBar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .apocalypseBackground

        // Normal state
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .apocalypseText.withAlphaComponent(0.6)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.apocalypseText.withAlphaComponent(0.6)
        ]

        // Selected state
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .apocalypsePrimary
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.apocalypsePrimary
        ]

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Configure NavigationBar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = .apocalypseBackground
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.apocalypseText
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.apocalypseText
        ]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = .apocalypsePrimary
    }
}

// MARK: - 根视图

/// 根视图：根据认证状态显示不同页面
struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var localizationManager: LocalizationManager

    var body: some View {
        Group {
            if !authManager.isInitialized {
                // 启动画面：检查会话中
                SplashView(authManager: authManager)
            } else if authManager.isAuthenticated {
                // 已登录：显示主界面
                ContentView()
                    .transition(.opacity)
            } else {
                // 未登录：显示认证页面
                AuthView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authManager.isInitialized)
        // 监听语言变化，确保 UI 更新
        .environment(\.locale, Locale(identifier: localizationManager.currentLanguageCode))
    }
}
