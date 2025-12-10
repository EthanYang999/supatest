//
//  LocationManager.swift
//  supatest
//
//  EarthLord Game - GPS 定位管理器
//  负责请求定位权限、获取用户 GPS 位置、路径追踪
//

import Foundation
import CoreLocation
import Combine  // @Published 需要这个框架

// MARK: - LocationManager

/// GPS 定位管理器
/// 管理用户位置权限请求、实时位置更新、路径追踪
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - 路径追踪属性 (Day 15)

    /// 是否正在追踪
    @Published var isTracking = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（每次路径变化时+1，触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（Day16 会用到）
    @Published var isPathClosed = false

    // MARK: - 速度检测属性 (Day 16)

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed = false

    // MARK: - 领地验证状态属性 (Day 17)

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil

    /// 计算出的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - Private Properties

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前 GPS 位置（私有，CLLocation 类型，用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 采点定时器
    private var pathUpdateTimer: Timer?

    /// 上次位置的时间戳（用于计算速度）
    private var lastLocationTimestamp: Date?

    // MARK: - 验证常量 (Day 16 + Day 17)

    /// 闭环距离阈值（起点和终点距离 ≤ 30米视为闭环）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数（至少 10 个点才能形成有效闭环）
    private let minimumPathPoints: Int = 10

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    // MARK: - Computed Properties

    /// 是否已授权定位
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// 是否被用户拒绝
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Initialization

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新
    }

    // MARK: - Public Methods

    /// 请求定位权限
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 路径追踪方法 (Day 15)

    /// 开始路径追踪
    func startPathTracking() {
        guard !isTracking else { return }

        isTracking = true
        pathCoordinates = []
        pathUpdateVersion = 0
        isPathClosed = false

        // 重置速度检测状态 (Day 16)
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil

        // 重置验证状态 (Day 17)
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // Day 16B: 记录日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 记录起点
        if let location = currentLocation {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            lastLocationTimestamp = location.timestamp
        }

        // 启动定时器，每2秒采集一次
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }
    }

    /// 停止路径追踪
    /// 会重置所有追踪相关状态，包括验证状态
    func stopPathTracking() {
        // Day 16B: 记录日志
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)

        isTracking = false
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // Day 18: 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0

        // 清空路径
        pathCoordinates = []
        pathUpdateVersion += 1
        isPathClosed = false
    }

    /// 清空路径（不停止追踪）
    func clearPath() {
        pathCoordinates = []
        pathUpdateVersion += 1
        isPathClosed = false

        // Day 18: 重置验证状态
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        guard isTracking, let location = currentLocation else { return }

        // 速度检测 (Day 16) - 超速时不记录该点
        guard validateMovementSpeed(newLocation: location) else { return }

        // 检查与上一个点的距离
        var distanceFromLast: Double = 0
        if let lastCoord = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            distanceFromLast = location.distance(from: lastLocation)

            // 距离超过10米才记录
            guard distanceFromLast > 10 else { return }
        }

        // 添加新坐标
        pathCoordinates.append(location.coordinate)
        pathUpdateVersion += 1

        // Day 16B: 记录日志
        TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(Int(distanceFromLast))m", type: .info)

        // 闭环检测 (Day 16)
        checkPathClosure()
    }

    // MARK: - 闭环检测方法 (Day 16)

    /// 检查路径是否形成闭环
    private func checkPathClosure() {
        // Day 16B: 已闭环则不再检测
        guard !isPathClosed else { return }

        // 1. 检查点数
        guard pathCoordinates.count >= minimumPathPoints else {
            print("❌ 路径点数不足: \(pathCoordinates.count)/\(minimumPathPoints)")
            return
        }

        // 2. 获取起点和当前位置
        guard let firstCoord = pathCoordinates.first,
              let currentLoc = currentLocation else {
            return
        }

        // 3. 计算距离（CLLocation.distance 内置 Haversine 公式）
        let startLocation = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
        let distance = currentLoc.distance(from: startLocation)

        // 4. 判断是否闭环
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            print("✅ 闭环检测成功! 距离起点: \(Int(distance))米")
            // Day 16B: 记录日志
            TerritoryLogger.shared.log("闭环成功！距起点 \(Int(distance))m", type: .success)

            // Day 17: 闭环成功后自动触发领地验证
            let validationResult = validateTerritory()
            territoryValidationPassed = validationResult.isValid
            territoryValidationError = validationResult.errorMessage
        } else {
            print("📍 距离起点: \(Int(distance))米 (需要 ≤\(Int(closureDistanceThreshold))米)")
            // Day 16B: 记录日志
            TerritoryLogger.shared.log("距起点 \(Int(distance))m (需≤30m)", type: .info)
        }
    }

    // MARK: - 速度检测方法 (Day 16)

    /// 验证移动速度是否正常
    /// - Returns: true 表示速度正常，false 表示超速（不记录该点）
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        guard let lastCoord = pathCoordinates.last,
              let lastTimestamp = lastLocationTimestamp else {
            lastLocationTimestamp = newLocation.timestamp
            return true
        }

        // 计算距离
        let lastLocation = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
        let distance = newLocation.distance(from: lastLocation)

        // 计算时间差
        let timeInterval = newLocation.timestamp.timeIntervalSince(lastTimestamp)
        guard timeInterval > 0 else { return false }

        // 计算速度 (m/s -> km/h)
        let speedMPS = distance / timeInterval
        let speedKMH = speedMPS * 3.6

        // 更新时间戳
        lastLocationTimestamp = newLocation.timestamp

        // 速度检测
        if speedKMH > 30 {
            speedWarning = "速度过快(\(Int(speedKMH))km/h)，已暂停记录"
            isOverSpeed = true
            // Day 16B: 记录日志
            TerritoryLogger.shared.log("超速 \(Int(speedKMH)) km/h，已停止追踪", type: .error)
            stopPathTracking()
            print("❌ 超速(\(Int(speedKMH))km/h)，自动停止追踪")
            return false
        } else if speedKMH > 15 {
            speedWarning = "移动速度较快: \(Int(speedKMH))km/h"
            isOverSpeed = true
            // Day 16B: 记录日志
            TerritoryLogger.shared.log("速度较快 \(Int(speedKMH)) km/h", type: .warning)
            print("⚠️ 速度警告: \(Int(speedKMH))km/h")
            return true  // 警告但继续记录
        } else {
            speedWarning = nil
            isOverSpeed = false
            return true
        }
    }

    // MARK: - 距离与面积计算 (Day 17)

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    private func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = CLLocation(latitude: pathCoordinates[i].latitude,
                                     longitude: pathCoordinates[i].longitude)
            let next = CLLocation(latitude: pathCoordinates[i + 1].latitude,
                                  longitude: pathCoordinates[i + 1].longitude)
            totalDistance += current.distance(from: next)
        }

        return totalDistance
    }

    /// 使用Shoelace公式(鞋带公式)计算多边形面积
    /// 考虑地球曲率的球面修正版本
    /// 公式：面积 = |Σ(lon2-lon1) × (2 + sin(lat1) + sin(lat2))| × R² / 2
    /// R = 6371000米（地球平均半径）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000  // 地球半径(米)
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)

        return area
    }

    // MARK: - 自相交检测 (Day 17)

    /// 判断两线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW辅助函数 - 判断三点的旋转方向
        /// - Returns: true表示逆时针(CCW)，false表示顺时针(CW)或共线
        /// 原理：使用向量叉积判断旋转方向
        /// ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
        /// 叉积 = (Cy - Ay) × (Bx - Ax) - (By - Ay) × (Cx - Ax)
        /// 叉积 > 0 → 逆时针，叉积 < 0 → 顺时针
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                               (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 两线段相交的条件：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测整条路径是否自相交
    /// - Returns: true 表示有自交（画了"8"字形等）
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量
        // 因为走圈回来时，首尾附近的线段物理位置很近，会被误判为相交
        let skipHeadCount = 2  // 跳过前2条线段
        let skipTailCount = 2  // 跳过后2条线段

        // 遍历每条线段 i
        for i in 0..<segmentCount {
            // ✅ 防御性索引检查
            guard i < pathSnapshot.count - 1 else {
                print("⚠️ 自交检测索引越界: i=\(i), count=\(pathSnapshot.count)")
                break
            }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            // 计算 j 的起始位置
            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            // 对比每条非相邻线段 j
            for j in startJ..<segmentCount {
                // ✅ 防御性索引检查
                guard j < pathSnapshot.count - 1 else {
                    print("⚠️ 自交检测索引越界: j=\(j), count=\(pathSnapshot.count)")
                    break
                }

                // ✅ 跳过首尾附近线段的比较（闭环时它们物理上很近，会误判）
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount
                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    // 发现自交
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    print("❌ 自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交")
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        print("✅ 自交检测通过")
        return false
    }

    // MARK: - 综合验证 (Day 17)

    /// 综合验证领地是否有效
    /// - Returns: (isValid: 是否有效, errorMessage: 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let error = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log(error, type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let error = "距离不足: \(Int(totalDistance))m (需≥\(Int(minimumTotalDistance))m)"
            TerritoryLogger.shared.log(error, type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("距离检查: \(Int(totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let error = "路径自相交（不能画8字形）"
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        calculatedArea = area
        if area < minimumEnclosedArea {
            let error = "面积不足: \(Int(area))m² (需≥\(Int(minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log(error, type: .error)
            TerritoryLogger.shared.log("领地验证失败", type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("面积检查: \(Int(area))m² ✓", type: .info)

        // 全部通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(Int(area))m²", type: .success)
        return (true, nil)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            // 如果已授权，自动开始定位
            if self.isAuthorized {
                self.startUpdatingLocation()
            }
        }
    }

    /// 位置更新回调
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.currentLocation = location  // 保存完整的 CLLocation 用于路径追踪
            self.locationError = nil
        }
    }

    /// 定位失败回调
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            // 用户拒绝权限时不显示错误
            if let clError = error as? CLError, clError.code == .denied {
                self.locationError = nil
                return
            }
            self.locationError = "定位失败：\(error.localizedDescription)"
        }
    }
}
