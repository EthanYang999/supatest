//
//  DebugPOIView.swift
//  supatest
//
//  EarthLord Game - Debug POI View
//  用于验证 POI 数据是否正确加载
//

import SwiftUI
import CoreLocation
import Supabase

// MARK: - POI 数据模型

struct POIItem: Identifiable, Decodable {
    let id: String
    let name: String
    let poi_type: String
    let latitude: Double
    let longitude: Double
    let discovered_by: UUID?
    let discovered_at: Date?
    let distance_meters: Double
}

// MARK: - DebugPOIView

struct DebugPOIView: View {
    @StateObject private var locationManager = LocationManager()

    @State private var pois: [POIItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchRadius: Double = 1000 // 默认 1000 米

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // 当前坐标显示
                coordinateCard

                // 搜索半径选择
                radiusSelector

                // 加载按钮
                loadButton

                // POI 列表
                poiList
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle("POI 调试")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.requestAuthorization()
        }
    }

    // MARK: - 坐标卡片

    private var coordinateCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                Text("当前坐标")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.text)
                Spacer()
            }

            if let location = locationManager.currentLocation {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("纬度")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.secondaryText)
                        Text(String(format: "%.6f", location.latitude))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.text)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("经度")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.secondaryText)
                        Text(String(format: "%.6f", location.longitude))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.text)
                    }

                    Spacer()
                }
            } else {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                    Text("正在获取位置...")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.secondaryText)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 搜索半径选择

    private var radiusSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("搜索半径: \(Int(searchRadius))米")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.text)

            Slider(value: $searchRadius, in: 100...5000, step: 100)
                .tint(ApocalypseTheme.primary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 加载按钮

    private var loadButton: some View {
        Button {
            Task {
                await loadNearbyPOIs()
            }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text(isLoading ? "加载中..." : "加载附近 POI")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                locationManager.currentLocation == nil || isLoading
                    ? ApocalypseTheme.primary.opacity(0.5)
                    : ApocalypseTheme.primary
            )
            .cornerRadius(12)
        }
        .disabled(locationManager.currentLocation == nil || isLoading)
    }

    // MARK: - POI 列表

    private var poiList: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题和数量
            HStack {
                Text("POI 列表")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.text)
                Spacer()
                Text("\(pois.count) 个")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }

            // 错误信息
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .padding(.vertical, 8)
            }

            // 列表
            if pois.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.secondaryText)
                    Text("暂无 POI 数据")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.secondaryText)
                    Text("点击上方按钮加载附近的 POI")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.secondaryText.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(pois) { poi in
                            poiRow(poi)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - POI 行

    private func poiRow(_ poi: POIItem) -> some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: iconForType(poi.poi_type))
                .font(.title2)
                .foregroundColor(colorForType(poi.poi_type))
                .frame(width: 40)

            // 名称和类型
            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.text)

                Text(poi.poi_type)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }

            Spacer()

            // 距离
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDistance(poi.distance_meters))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.primary)

                Text("距离")
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.secondaryText)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    // MARK: - 辅助方法

    private func iconForType(_ type: String) -> String {
        switch type {
        case "hospital": return "cross.case.fill"
        case "supermarket": return "cart.fill"
        case "factory": return "building.2.fill"
        case "gas_station": return "fuelpump.fill"
        case "school": return "book.fill"
        case "police_station": return "shield.fill"
        case "residential": return "house.fill"
        default: return "mappin.circle.fill"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "hospital": return .red
        case "supermarket": return .green
        case "factory": return .gray
        case "gas_station": return .orange
        case "school": return .blue
        case "police_station": return .indigo
        case "residential": return .brown
        default: return ApocalypseTheme.primary
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }

    // MARK: - 加载数据

    private func loadNearbyPOIs() async {
        guard let location = locationManager.currentLocation else { return }

        isLoading = true
        errorMessage = nil

        do {
            let response: [POIItem] = try await supabase.rpc(
                "get_pois_within_radius",
                params: [
                    "p_lat": location.latitude,
                    "p_lon": location.longitude,
                    "p_radius_meters": searchRadius
                ]
            ).execute().value

            await MainActor.run {
                pois = response
                isLoading = false
                print("✅ 加载到 \(response.count) 个 POI")
            }
        } catch {
            await MainActor.run {
                errorMessage = "加载失败: \(error.localizedDescription)"
                isLoading = false
                print("❌ 加载 POI 失败: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DebugPOIView()
    }
}
