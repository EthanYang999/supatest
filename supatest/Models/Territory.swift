//
//  Territory.swift
//  supatest
//
//  EarthLord Game - 领地数据模型
//  用于存储和解析来自 Supabase 的领地数据
//

import Foundation
import CoreLocation

// MARK: - Territory

/// 领地数据模型
/// 对应 Supabase 中的 territories 表
struct Territory: Codable, Identifiable {

    // MARK: - Properties

    /// 领地唯一标识符
    let id: String

    /// 所属用户 ID
    let userId: String

    /// 路径坐标数组
    /// 格式：[{"lat": x, "lon": y}, ...]
    let path: [[String: Double]]

    /// 领地面积（平方米）
    let area: Double

    /// 路径点数量（可选）
    let pointCount: Int?

    /// 是否激活（可选）
    let isActive: Bool?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
    }

    // MARK: - Methods

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    /// - Returns: 坐标数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
