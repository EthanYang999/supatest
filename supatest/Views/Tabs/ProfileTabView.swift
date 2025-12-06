//
//  ProfileTabView.swift
//  supatest
//
//  EarthLord Game - Profile Tab
//

import SwiftUI

struct ProfileTabView: View {
    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("个人")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)

                Text("查看个人信息")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }
        }
    }
}

#Preview {
    ProfileTabView()
}
