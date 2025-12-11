//
//  TerritoryDetailView.swift
//  supatest
//
//  EarthLord Game - 领地详情页
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    let territory: Territory
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var territoryManager = TerritoryManager.shared

    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var mapCameraPosition: MapCameraPosition

    init(territory: Territory, onDelete: (() -> Void)? = nil) {
        self.territory = territory
        self.onDelete = onDelete

        // 计算领地中心点
        let coords = territory.toCoordinates()
        if !coords.isEmpty {
            let avgLat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
            let avgLon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
            _mapCameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )))
        } else {
            _mapCameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreview
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)

                    // 基本信息
                    infoSection

                    // 操作按钮
                    actionsSection

                    // 占位功能
                    placeholderSection
                }
                .padding(.vertical)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteTerritory()
                }
            } message: {
                Text("删除后无法恢复，确定要删除这块领地吗？")
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        ProgressView("删除中...")
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    /// 地图预览
    private var mapPreview: some View {
        Map(position: $mapCameraPosition) {
            // 空内容，只显示地图
        }
        .mapStyle(.hybrid)
        .disabled(true)
    }

    /// 基本信息
    private var infoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("领地信息")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.text)
                Spacer()
            }

            VStack(spacing: 8) {
                infoRow(icon: "map", title: "面积", value: territory.formattedArea)
                infoRow(icon: "mappin.circle", title: "路径点", value: String(localized: "\(territory.pointCount ?? 0) 个"))

                if let createdAt = territory.createdAt {
                    infoRow(icon: "clock", title: "创建时间", value: formatDate(createdAt))
                }
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    /// 操作按钮
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // 删除按钮
            Button(action: {
                showDeleteAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("删除领地")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    /// 占位功能区
    private var placeholderSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("更多功能")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.text)
                Spacer()
            }

            // 重命名（占位）
            placeholderButton(icon: "pencil", title: "重命名领地")

            // 建筑系统（占位）
            placeholderButton(icon: "building.2", title: "建筑系统")

            // 领地交易（占位）
            placeholderButton(icon: "arrow.left.arrow.right", title: "领地交易")
        }
        .padding(.horizontal)
    }

    /// 占位按钮
    private func placeholderButton(icon: String, title: LocalizedStringKey) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.secondaryText)
            Text(title)
                .foregroundColor(ApocalypseTheme.text)
            Spacer()
            Text("敬请期待")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground.opacity(0.5))
        .cornerRadius(12)
    }

    /// 信息行
    private func infoRow(icon: String, title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 24)
            Text(title)
                .foregroundColor(ApocalypseTheme.secondaryText)
            Spacer()
            Text(value)
                .foregroundColor(ApocalypseTheme.text)
        }
    }

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // 尝试带毫秒解析
        if let date = formatter.date(from: dateString) {
            return formatDateDisplay(date)
        }

        // 尝试不带毫秒解析
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return formatDateDisplay(date)
        }

        return dateString
    }

    private func formatDateDisplay(_ date: Date) -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }

    private func deleteTerritory() {
        isDeleting = true
        Task {
            let success = await territoryManager.deleteTerritory(territoryId: territory.id)
            await MainActor.run {
                isDeleting = false
                if success {
                    onDelete?()
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test",
            userId: "user",
            name: "测试领地",
            path: [],
            area: 1234,
            pointCount: 15,
            isActive: true,
            completedAt: nil,
            startedAt: nil,
            createdAt: nil
        )
    )
}
