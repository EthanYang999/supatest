//
//  LanguageSettingsView.swift
//  supatest
//
//  EarthLord 游戏语言设置页面
//

import SwiftUI

struct LanguageSettingsView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    languageRow(language: language)
                }
            } header: {
                Text("选择语言")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } footer: {
                Text("更改语言后，应用界面将立即切换到所选语言。")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .listRowBackground(ApocalypseTheme.cardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(ApocalypseTheme.background)
        .navigationTitle("语言设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func languageRow(language: AppLanguage) -> some View {
        Button(action: {
            localizationManager.setLanguage(language)
        }) {
            HStack {
                // 语言图标
                Text(language.flag)
                    .font(.title2)

                // 语言名称
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .foregroundColor(ApocalypseTheme.text)
                        .fontWeight(localizationManager.currentLanguage == language ? .semibold : .regular)

                    Text(language.nativeName)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 选中标记
                if localizationManager.currentLanguage == language {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LanguageSettingsView()
    }
}
