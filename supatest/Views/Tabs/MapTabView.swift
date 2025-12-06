//
//  MapTabView.swift
//  supatest
//
//  EarthLord Game - Map Tab
//

import SwiftUI

struct MapTabView: View {
    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("地图")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)

                Text("探索末日世界")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }
        }
    }
}

#Preview {
    MapTabView()
}
