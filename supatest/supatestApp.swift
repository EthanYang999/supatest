//
//  supatestApp.swift
//  supatest
//
//  Created by Ethan on 12/5/25.
//

import SwiftUI

@main
struct supatestApp: App {

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
