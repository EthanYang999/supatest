//
//  MapViewRepresentable.swift
//  supatest
//
//  EarthLord Game - Apocalypse Map View
//

import SwiftUI
import MapKit

// MARK: - POI Annotation

/// POI 标注类
class POIAnnotation: NSObject, MKAnnotation {
    let poi: POI
    let isDiscovered: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: poi.latitude, longitude: poi.longitude)
    }

    var title: String? {
        isDiscovered ? poi.name : "???"
    }

    var subtitle: String? {
        isDiscovered ? poi.poiType.localizedDisplayName : nil
    }

    init(poi: POI, isDiscovered: Bool) {
        self.poi = poi
        self.isDiscovered = isDiscovered
        super.init()
    }
}

// MARK: - POI Type Extension

extension String {
    /// POI 类型的本地化显示名称
    var localizedDisplayName: String {
        switch self {
        case "hospital": return String(localized: "医院")
        case "supermarket": return String(localized: "超市")
        case "factory": return String(localized: "工厂")
        case "gas_station": return String(localized: "加油站")
        case "school": return String(localized: "学校")
        case "police_station": return String(localized: "警察局")
        case "residential": return String(localized: "住宅区")
        case "park": return String(localized: "公园")
        case "restaurant": return String(localized: "餐厅")
        case "pharmacy": return String(localized: "药房")
        default: return String(localized: "未知地点")
        }
    }

    /// POI 类型对应的 SF Symbol 图标
    var poiIconName: String {
        switch self {
        case "hospital": return "cross.case.fill"
        case "supermarket": return "cart.fill"
        case "factory": return "building.2.fill"
        case "gas_station": return "fuelpump.fill"
        case "school": return "book.fill"
        case "police_station": return "shield.fill"
        case "residential": return "house.fill"
        case "park": return "leaf.fill"
        case "restaurant": return "fork.knife"
        case "pharmacy": return "pills.fill"
        default: return "mappin.circle.fill"
        }
    }

    /// POI 类型对应的颜色
    var poiColor: UIColor {
        switch self {
        case "hospital": return UIColor.systemRed
        case "supermarket": return UIColor.systemGreen
        case "factory": return UIColor.systemGray
        case "gas_station": return UIColor.systemOrange
        case "school": return UIColor.systemBlue
        case "police_station": return UIColor.systemIndigo
        case "residential": return UIColor.systemBrown
        case "park": return UIColor.systemMint
        case "restaurant": return UIColor.systemYellow
        case "pharmacy": return UIColor.systemPink
        default: return UIColor.systemTeal
        }
    }
}

// MARK: - MapViewRepresentable

struct MapViewRepresentable: UIViewRepresentable {
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var shouldCenterOnUser: Bool

    /// 附近的 POI 列表
    var nearbyPOIs: [POI]

    /// 已发现的 POI ID 集合
    var discoveredPOIIds: Set<String>

    /// POI 点击回调
    var onPOITapped: ((POI) -> Void)?

    /// 三指点击回调（用于 Debug 模式）
    var onTripleFingerTap: (() -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // 显示用户位置（蓝点）
        mapView.showsUserLocation = true

        // 使用卫星+道路标签混合模式
        mapView.mapType = .hybrid

        // 禁用 3D 倾斜和建筑显示
        mapView.isPitchEnabled = false
        mapView.showsBuildings = false

        // 隐藏系统 POI 标签（末日风格）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏指南针和比例尺（简洁界面）
        mapView.showsCompass = false
        mapView.showsScale = false

        // 注册自定义标注视图
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: "POIMarker"
        )

        // 应用末日风格滤镜
        applyApocalypseFilter(to: mapView)

        // 添加三指点击手势（用于 Debug 模式模拟发现）
        #if DEBUG
        let tripleFingerTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTripleFingerTap)
        )
        tripleFingerTap.numberOfTouchesRequired = 3
        tripleFingerTap.numberOfTapsRequired = 1
        mapView.addGestureRecognizer(tripleFingerTap)
        #endif

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 自动居中到用户位置
        if shouldCenterOnUser, let location = userLocation {
            let region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
            mapView.setRegion(region, animated: true)

            // 重置标志，避免重复居中
            DispatchQueue.main.async {
                shouldCenterOnUser = false
            }
        }

        // 更新 POI 标注
        context.coordinator.updatePOIAnnotations(
            mapView: mapView,
            pois: nearbyPOIs,
            discoveredIds: discoveredPOIIds
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Apocalypse Filter

    /// 应用末日风格滤镜：降低亮度和饱和度，添加棕褐色调
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 创建 CIFilter 滤镜组合
        // 1. 降低饱和度
        let saturationFilter = CIFilter(name: "CIColorControls")
        saturationFilter?.setValue(0.6, forKey: kCIInputSaturationKey)
        saturationFilter?.setValue(-0.1, forKey: kCIInputBrightnessKey)
        saturationFilter?.setValue(1.1, forKey: kCIInputContrastKey)

        // 2. 添加棕褐色调（Sepia）
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.3, forKey: kCIInputIntensityKey)

        // 组合滤镜效果通过 CALayer
        let overlayView = UIView(frame: mapView.bounds)
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.backgroundColor = UIColor(red: 0.15, green: 0.12, blue: 0.08, alpha: 0.35)
        overlayView.isUserInteractionEnabled = false
        overlayView.tag = 999 // 用于识别

        mapView.addSubview(overlayView)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        var isFirstLocationUpdate = true

        /// 当前地图上的 POI 标注缓存（用于增量更新）
        private var currentAnnotations: [String: POIAnnotation] = [:]

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - POI Annotation Update

        /// 增量更新 POI 标注
        func updatePOIAnnotations(mapView: MKMapView, pois: [POI], discoveredIds: Set<String>) {
            let newPOIIds = Set(pois.map { $0.id })
            let existingPOIIds = Set(currentAnnotations.keys)

            // 需要移除的标注
            let idsToRemove = existingPOIIds.subtracting(newPOIIds)
            for id in idsToRemove {
                if let annotation = currentAnnotations[id] {
                    mapView.removeAnnotation(annotation)
                    currentAnnotations.removeValue(forKey: id)
                }
            }

            // 需要添加或更新的标注
            for poi in pois {
                let isDiscovered = discoveredIds.contains(poi.id)

                if let existingAnnotation = currentAnnotations[poi.id] {
                    // 检查发现状态是否变化
                    if existingAnnotation.isDiscovered != isDiscovered {
                        // 状态变化，移除旧的，添加新的
                        mapView.removeAnnotation(existingAnnotation)
                        let newAnnotation = POIAnnotation(poi: poi, isDiscovered: isDiscovered)
                        mapView.addAnnotation(newAnnotation)
                        currentAnnotations[poi.id] = newAnnotation
                    }
                    // 位置相同且状态相同，无需更新
                } else {
                    // 新增标注
                    let annotation = POIAnnotation(poi: poi, isDiscovered: isDiscovered)
                    mapView.addAnnotation(annotation)
                    currentAnnotations[poi.id] = annotation
                }
            }
        }

        // MARK: - MKMapViewDelegate

        // 用户位置更新时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            let coordinate = userLocation.coordinate

            // 更新父视图的位置
            parent.userLocation = coordinate

            // 首次定位成功时，立即居中到用户位置
            if isFirstLocationUpdate {
                isFirstLocationUpdate = false
                let region = MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 500,
                    longitudinalMeters: 500
                )
                mapView.setRegion(region, animated: true)

                // 重置标志
                DispatchQueue.main.async {
                    self.parent.shouldCenterOnUser = false
                }
            }
        }

        // 地图开始拖动时
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // 用户开始手动拖动地图
        }

        // 地图结束拖动时
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 用户结束手动拖动地图
        }

        // 自定义标注视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 保持默认用户位置蓝点样式
            if annotation is MKUserLocation {
                return nil
            }

            // POI 标注
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POIMarker"
                let annotationView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: identifier,
                    for: annotation
                ) as! MKMarkerAnnotationView

                configureAnnotationView(annotationView, for: poiAnnotation)
                return annotationView
            }

            return nil
        }

        /// 配置 POI 标注视图
        private func configureAnnotationView(_ view: MKMarkerAnnotationView, for annotation: POIAnnotation) {
            let poiType = annotation.poi.poiType

            if annotation.isDiscovered {
                // 已发现的 POI：彩色图标
                view.markerTintColor = poiType.poiColor
                view.glyphImage = UIImage(systemName: poiType.poiIconName)
                view.glyphTintColor = .white
                view.displayPriority = .defaultHigh
            } else {
                // 未发现的 POI：灰色带问号
                view.markerTintColor = UIColor.systemGray
                view.glyphImage = UIImage(systemName: "questionmark")
                view.glyphTintColor = .white
                view.displayPriority = .defaultLow
            }

            // 允许显示标注气泡
            view.canShowCallout = true

            // 添加详情按钮（仅已发现的 POI）
            if annotation.isDiscovered {
                let detailButton = UIButton(type: .detailDisclosure)
                view.rightCalloutAccessoryView = detailButton
            } else {
                view.rightCalloutAccessoryView = nil
            }

            // 动画效果
            view.animatesWhenAdded = true
        }

        // 点击标注气泡的附件按钮
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let poiAnnotation = view.annotation as? POIAnnotation {
                parent.onPOITapped?(poiAnnotation.poi)
            }
        }

        // 点击标注本身
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // 可选：点击标注时的额外处理
        }

        // MARK: - Debug Gesture Handler

        #if DEBUG
        /// 处理三指点击手势
        @objc func handleTripleFingerTap() {
            print("🔧 [DEBUG] 检测到三指点击")
            parent.onTripleFingerTap?()
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        shouldCenterOnUser: .constant(true),
        nearbyPOIs: [],
        discoveredPOIIds: [],
        onPOITapped: nil,
        onTripleFingerTap: nil
    )
    .ignoresSafeArea()
}
