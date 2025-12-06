//
//  CommunicationTabView.swift
//  supatest
//
//  EarthLord Game - Communication Tab
//

import SwiftUI

struct CommunicationTabView: View {
    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("通讯")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.text)

                Text("与其他幸存者联系")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }
        }
    }
}

#Preview {
    CommunicationTabView()
}
