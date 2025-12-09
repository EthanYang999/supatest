//
//  LocationManager.swift
//  supatest
//
//  EarthLord Game - Location Manager
//

import Foundation
import CoreLocation
import Combine

/// 位置管理器 - 处理用户位置权限和更新
class LocationManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    /// 当前用户位置
    @Published var currentLocation: CLLocationCoordinate2D?

    /// 位置授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 是否正在定位
    @Published var isLocating: Bool = false

    /// 位置错误信息
    @Published var locationError: LocationError?

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private var hasLoggedFirstLocation = false

    // MARK: - Location Errors

    enum LocationError: LocalizedError {
        case denied
        case restricted
        case unknown

        var errorDescription: String? {
            switch self {
            case .denied:
                return "位置权限被拒绝"
            case .restricted:
                return "位置服务受限"
            case .unknown:
                return "未知定位错误"
            }
        }
    }

    // MARK: - Initialization

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 每移动10米更新一次
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public Methods

    /// 请求位置权限
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始定位
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }

        isLocating = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止定位
    func stopUpdatingLocation() {
        isLocating = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求单次位置
    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }

        isLocating = true
        locationError = nil
        locationManager.requestLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
        isLocating = false

        // 首次定位成功时输出坐标
        if !hasLoggedFirstLocation {
            hasLoggedFirstLocation = true
            print("📍 当前坐标: 纬度 \(String(format: "%.6f", location.coordinate.latitude)), 经度 \(String(format: "%.6f", location.coordinate.longitude))")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false

        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = .denied
            case .locationUnknown:
                locationError = .unknown
            default:
                locationError = .unknown
            }
        } else {
            locationError = .unknown
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied:
            locationError = .denied
        case .restricted:
            locationError = .restricted
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}
