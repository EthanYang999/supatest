//
//  LanguageSettingsView.swift
//  supatest
//
//  EarthLord 游戏语言设置页面
//  支持三种选项：跟随系统、简体中文、English
//

import SwiftUI

struct LanguageSettingsView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                ForEach(LanguageOption.allCases) { option in
                    languageRow(option: option)
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

    // MARK: - 语言行视图

    private func languageRow(option: LanguageOption) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                localizationManager.setLanguage(option)
            }
        }) {
            HStack(spacing: 12) {
                // 语言图标
                Text(option.flag)
                    .font(.title2)

                // 语言名称
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .foregroundColor(ApocalypseTheme.text)
                        .fontWeight(localizationManager.selectedOption == option ? .semibold : .regular)

                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 选中标记
                if localizationManager.selectedOption == option {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                        .font(.title3)
                        .transition(.scale.combined(with: .opacity))
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
