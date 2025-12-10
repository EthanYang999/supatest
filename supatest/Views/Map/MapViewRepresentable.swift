//
//  MapViewRepresentable.swift
//  supatest
//
//  EarthLord Game - MKMapView 的 SwiftUI 包装器
//  提供末世风格的卫星地图显示，支持用户位置追踪和自动居中
//

import SwiftUI
import MapKit

// MARK: - MapViewRepresentable

/// MKMapView 的 SwiftUI 包装器
/// 显示末世风格的卫星地图，首次获得位置时自动居中
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - Bindings

    /// 用户当前位置
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位居中
    @Binding var hasLocatedUser: Bool

    // MARK: - 路径追踪属性 (Day 15)

    /// 路径坐标数组（WGS-84 原始坐标）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号（变化时触发重绘）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否闭合 (Day 16)
    var isPathClosed: Bool

    // MARK: - Day 18-B3: 领地显示属性

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID（用于区分我的领地和他人领地）
    var currentUserId: String?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 地图类型：卫星图+道路标签（符合末世废土风格）
        mapView.mapType = .hybrid

        // 隐藏 POI 标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏 3D 建筑
        mapView.showsBuildings = false

        // 显示用户位置蓝点（关键！这会触发 MapKit 获取位置）
        mapView.showsUserLocation = true

        // 允许用户交互
        mapView.isZoomEnabled = true    // 允许双指缩放
        mapView.isScrollEnabled = true  // 允许单指拖动
        mapView.isRotateEnabled = true  // 允许旋转
        mapView.isPitchEnabled = true   // 允许倾斜

        // 设置代理（关键！否则 didUpdate userLocation 不会被调用）
        mapView.delegate = context.coordinator

        // ⚠️ 末世滤镜已关闭（性能优化）
        // applyApocalypseFilter(to: mapView)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 更新路径（当 pathUpdateVersion 变化时触发）
        updateTrackingPath(on: uiView)

        // Day 18-B3: 绘制云端领地
        drawTerritories(on: uiView)
    }

    // MARK: - 路径更新方法 (Day 15 + Day 16)

    /// 更新追踪路径
    private func updateTrackingPath(on mapView: MKMapView) {
        // 移除旧的轨迹和多边形
        let existingOverlays = mapView.overlays.filter { $0 is MKPolyline || $0 is MKPolygon }
        mapView.removeOverlays(existingOverlays)

        // 如果路径少于2个点，不绘制
        guard trackingPath.count >= 2 else { return }

        // ⭐ 关键：WGS-84 → GCJ-02 坐标转换（中国地图偏移修正）
        let gcjCoordinates = trackingPath.map { coord in
            CoordinateConverter.wgs84ToGcj02(latitude: coord.latitude, longitude: coord.longitude)
        }

        // 创建折线
        let polyline = MKPolyline(coordinates: gcjCoordinates, count: gcjCoordinates.count)

        // 添加到地图（⭐ 关键：使用 aboveRoads 层级确保可见）
        mapView.addOverlay(polyline, level: .aboveRoads)

        // Day 16: 闭环后添加多边形填充
        if isPathClosed && gcjCoordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: gcjCoordinates, count: gcjCoordinates.count)
            polygon.title = "tracking"  // Day 18-B3: 标记为正在追踪的多边形
            mapView.addOverlay(polygon, level: .aboveRoads)
        }
    }

    // MARK: - Day 18-B3: 领地绘制方法

    /// 绘制云端领地
    /// 我的领地 = 绿色，他人领地 = 橙色
    private func drawTerritories(on mapView: MKMapView) {
        // 移除旧的领地多边形（保留 tracking 和 polyline）
        let territoryOverlays = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                return polygon.title == "mine" || polygon.title == "others"
            }
            return false
        }
        mapView.removeOverlays(territoryOverlays)

        // 绘制每个领地
        for territory in territories {
            let coordinates = territory.toCoordinates()
            guard coordinates.count >= 3 else { continue }

            // ⭐ 关键：WGS-84 → GCJ-02 坐标转换（中国地图偏移修正）
            let gcjCoordinates = coordinates.map { coord in
                CoordinateConverter.wgs84ToGcj02(latitude: coord.latitude, longitude: coord.longitude)
            }

            // 创建多边形
            let polygon = MKPolygon(coordinates: gcjCoordinates, count: gcjCoordinates.count)

            // ⚠️ 关键：比较 userId 时必须统一大小写！
            // 数据库存储的是小写 UUID，iOS uuidString 返回大写
            let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
            polygon.title = isMine ? "mine" : "others"

            // 添加到地图
            mapView.addOverlay(polygon, level: .aboveRoads)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Apocalypse Filter

    /// 应用末世滤镜效果
    /// 降低饱和度、添加棕褐色调，营造废土氛围
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度
        guard let colorControls = CIFilter(name: "CIColorControls") else { return }
        colorControls.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls.setValue(0.5, forKey: kCIInputSaturationKey)    // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        guard let sepiaFilter = CIFilter(name: "CISepiaTone") else { return }
        sepiaFilter.setValue(0.65, forKey: kCIInputIntensityKey)

        // 应用到地图图层
        mapView.layer.filters = [colorControls, sepiaFilter]
    }

    // MARK: - Coordinator

    /// 地图代理，处理用户位置更新和地图事件
    class Coordinator: NSObject, MKMapViewDelegate {

        var parent: MapViewRepresentable

        /// 首次居中标志，防止重复居中（不影响用户手动拖动）
        private var hasInitialCentered = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：用户位置更新时调用
        /// 首次获得位置时自动平滑居中地图
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else { return }

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 首次获得位置时，自动居中地图
            guard !hasInitialCentered else { return }

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        /// 地图区域变化回调
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 预留：可用于后续功能扩展
        }

        /// 地图加载完成回调
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // 预留：可用于后续功能扩展
        }

        // MARK: - 轨迹渲染 (Day 15 + Day 16)

        /// ⭐ 关键方法：为 overlay 提供渲染器
        /// 没有这个方法，MKPolyline 不会显示！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 折线渲染（轨迹）
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // Day 16: 根据闭环状态切换颜色
                if parent.isPathClosed {
                    renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.9)  // 绿色（闭环）
                } else {
                    renderer.strokeColor = UIColor.systemCyan.withAlphaComponent(0.9)   // 青色（未闭环）
                }

                renderer.lineWidth = 6               // 6点宽度
                renderer.lineCap = .round            // 圆角端点
                renderer.lineJoin = .round           // 圆角连接
                return renderer
            }

            // Day 16 + Day 18-B3: 多边形渲染
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据 title 区分不同类型的多边形
                switch polygon.title {
                case "mine":
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2.0

                case "others":
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                    renderer.lineWidth = 2.0

                case "tracking":
                    // 正在追踪的多边形：绿色（闭环状态）
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2.0

                default:
                    // 默认：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2.0
                }

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        trackingPath: .constant([]),
        pathUpdateVersion: 0,
        isTracking: false,
        isPathClosed: false,
        territories: [],
        currentUserId: nil
    )
    .ignoresSafeArea()
}
