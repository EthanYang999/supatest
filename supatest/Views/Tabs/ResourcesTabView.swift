//
//  ResourcesTabView.swift
//  supatest
//
//  EarthLord Game - Resources Tab
//

import SwiftUI

struct ResourcesTabView: View {
    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("资源")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)

                Text("收集和管理资源")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }
        }
    }
}

#Preview {
    ResourcesTabView()
}
