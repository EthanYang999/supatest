//
//  TestMenuView.swift
//  supatest
//
//  EarthLord Game - 测试入口菜单
//  提供开发测试功能的入口，包括 Supabase 连接测试和圈地功能测试
//
//  ⚠️ 注意：此视图不套 NavigationStack，因为它已在 ContentView 的 NavigationStack 内部
//

import SwiftUI

// MARK: - TestMenuView

/// 测试入口菜单视图
struct TestMenuView: View {

    // MARK: - Body

    var body: some View {
        List {
            // MARK: - 测试功能列表

            Section {
                // Supabase 连接测试
                NavigationLink {
                    SupabaseTestView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 20))
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Supabase 连接测试")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.text)

                            Text("测试数据库连接状态")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 圈地功能测试
                NavigationLink {
                    TerritoryTestView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ApocalypseTheme.primary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("圈地功能测试")
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.text)

                            Text("查看圈地模块运行日志")
                                .font(.caption)
                                .foregroundColor(ApocalypseTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("测试功能")
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }

            // MARK: - 说明信息

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("开发说明")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.text)

                    Text("这些测试功能仅供开发调试使用，正式版本将会隐藏。")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.secondaryText)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("开发测试")
        .listStyle(.insetGrouped)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
