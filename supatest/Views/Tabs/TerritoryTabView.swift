//
//  TerritoryTabView.swift
//  supatest
//
//  EarthLord Game - Territory Tab
//

import SwiftUI

struct TerritoryTabView: View {
    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("领地")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)

                Text("管理你的领土")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }
        }
    }
}

#Preview {
    TerritoryTabView()
}
