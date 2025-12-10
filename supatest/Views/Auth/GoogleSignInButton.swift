//
//  GoogleSignInButton.swift
//  supatest
//
//  EarthLord 游戏 - Google 登录按钮组件
//

import SwiftUI
import GoogleSignIn

struct GoogleSignInButton: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Button(action: performGoogleSignIn) {
            HStack {
                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 20))
                }
                Text("通过 Google 登录")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
        }
        .disabled(authManager.isLoading)
    }

    private func performGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        let presentingVC = rootViewController.presentedViewController ?? rootViewController

        Task {
            await authManager.signInWithGoogle(presenting: presentingVC)
        }
    }
}

#Preview {
    GoogleSignInButton()
        .environmentObject(AuthManager.shared)
        .padding()
        .background(Color.gray)
}
