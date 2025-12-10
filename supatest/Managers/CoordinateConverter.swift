//
//  CoordinateConverter.swift
//  supatest
//
//  EarthLord Game - 坐标转换工具
//  处理中国 GPS 偏移问题：WGS-84 (GPS原始坐标) ↔ GCJ-02 (火星坐标系)
//
//  为什么需要坐标转换？
//  - GPS 硬件返回 WGS-84 坐标（国际标准）
//  - 中国法规要求地图使用 GCJ-02 坐标（加密偏移）
//  - 苹果地图的蓝点自动处理了偏移，但手动绘制的 MKPolyline 不会自动转换
//  - 如果不转换，轨迹会偏移 100-500 米！
//

import Foundation
import CoreLocation

// MARK: - CoordinateConverter

/// 坐标转换工具 - 处理中国 GPS 偏移问题
class CoordinateConverter {

    // MARK: - 地球椭球参数

    /// 长半轴（米）
    private static let a = 6378245.0

    /// 偏心率平方
    private static let ee = 0.00669342162296594323

    /// 圆周率
    private static let pi = Double.pi

    // MARK: - 公开方法

    /// 判断坐标是否在中国境内
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: 是否在中国境内
    static func isInChina(latitude: Double, longitude: Double) -> Bool {
        // 中国大致范围：纬度 0.8293 ~ 55.8271，经度 72.004 ~ 137.8347
        // 这里使用简化的矩形判断
        return longitude > 73.66 && longitude < 135.05 && latitude > 3.86 && latitude < 53.55
    }

    /// WGS-84 → GCJ-02 转换
    /// - Parameters:
    ///   - latitude: WGS-84 纬度
    ///   - longitude: WGS-84 经度
    /// - Returns: GCJ-02 坐标
    static func wgs84ToGcj02(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        // 不在中国境内，不需要转换
        if !isInChina(latitude: latitude, longitude: longitude) {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        // 计算偏移量
        var dLat = transformLatitude(longitude - 105.0, latitude - 35.0)
        var dLon = transformLongitude(longitude - 105.0, latitude - 35.0)

        let radLat = latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        let gcjLat = latitude + dLat
        let gcjLon = longitude + dLon

        return CLLocationCoordinate2D(latitude: gcjLat, longitude: gcjLon)
    }

    /// GCJ-02 → WGS-84 转换（逆向转换，上传数据时会用到）
    /// - Parameters:
    ///   - latitude: GCJ-02 纬度
    ///   - longitude: GCJ-02 经度
    /// - Returns: WGS-84 坐标
    static func gcj02ToWgs84(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        // 不在中国境内，不需要转换
        if !isInChina(latitude: latitude, longitude: longitude) {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        // 使用迭代法进行逆向转换
        let gcj = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        var wgs = gcj
        var temp: CLLocationCoordinate2D

        // 迭代计算
        for _ in 0..<10 {
            temp = wgs84ToGcj02(latitude: wgs.latitude, longitude: wgs.longitude)
            wgs.latitude += gcj.latitude - temp.latitude
            wgs.longitude += gcj.longitude - temp.longitude
        }

        return wgs
    }

    // MARK: - 私有转换方法

    /// 纬度偏移计算
    private static func transformLatitude(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度偏移计算
    private static func transformLongitude(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
