//
//  TerritoryTabView.swift
//  supatest
//
//  EarthLord Game - 领地管理页面
//

import SwiftUI

struct TerritoryTabView: View {

    @StateObject private var territoryManager = TerritoryManager.shared
    @State private var myTerritories: [Territory] = []
    @State private var isLoading = false
    @State private var selectedTerritory: Territory?

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("加载中...")
                        .foregroundColor(ApocalypseTheme.text)
                } else if myTerritories.isEmpty {
                    emptyStateView
                } else {
                    territoryListView
                }
            }
            .navigationTitle("我的领地")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadTerritories()
            }
            .refreshable {
                await loadTerritoriesAsync()
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(
                    territory: territory,
                    onDelete: {
                        // 删除后刷新列表
                        loadTerritories()
                    }
                )
            }
        }
    }

    // MARK: - Subviews

    /// 统计头部
    private var statsHeader: some View {
        HStack(spacing: 20) {
            // 领地数量
            VStack {
                Text("\(myTerritories.count)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.primary)
                Text("领地数")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }

            Divider()
                .frame(height: 40)

            // 总面积
            VStack {
                Text(totalAreaFormatted)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.primary)
                Text("总面积")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    /// 领地列表
    private var territoryListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计信息
                statsHeader
                    .padding(.horizontal)

                // 领地卡片列表
                ForEach(myTerritories) { territory in
                    TerritoryCardView(territory: territory)
                        .onTapGesture {
                            selectedTerritory = territory
                        }
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.secondaryText)

            Text("还没有领地")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.text)

            Text("去地图页面开始圈地吧！")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.secondaryText)
        }
    }

    // MARK: - Helpers

    private var totalAreaFormatted: String {
        let total = myTerritories.reduce(0) { $0 + $1.area }
        if total >= 1_000_000 {
            return String(format: "%.2f km²", total / 1_000_000)
        } else {
            return String(format: "%.0f m²", total)
        }
    }

    private func loadTerritories() {
        isLoading = true
        Task {
            await loadTerritoriesAsync()
        }
    }

    private func loadTerritoriesAsync() async {
        do {
            let territories = try await territoryManager.loadMyTerritories()
            await MainActor.run {
                myTerritories = territories
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
            print("❌ 加载领地失败: \(error)")
        }
    }
}

// MARK: - Territory Card View

struct TerritoryCardView: View {
    let territory: Territory

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                // 名称
                Text(territory.displayName)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.text)

                // 信息
                HStack(spacing: 16) {
                    Label(territory.formattedArea, systemImage: "map")
                    Label("\(territory.pointCount ?? 0) 点", systemImage: "mappin.circle")
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(ApocalypseTheme.secondaryText)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    TerritoryTabView()
}
