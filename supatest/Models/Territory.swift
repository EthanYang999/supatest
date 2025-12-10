//
//  Territory.swift
//  supatest
//
//  EarthLord Game - 领地数据模型
//  用于解析从 Supabase 拉取的领地数据
//

import Foundation
import CoreLocation

// MARK: - Territory Model

/// 领地数据模型
/// 用于解析从 Supabase 拉取的领地数据
struct Territory: Codable, Identifiable {

    // MARK: - Properties

    let id: String
    let userId: String
    let name: String?              // 可选，数据库允许为空
    let path: [[String: Double]]   // 格式：[{"lat": x, "lon": y}]
    let area: Double
    let pointCount: Int?           // 可选，防止解码失败
    let isActive: Bool?            // 可选，防止解码失败

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
    }

    // MARK: - Methods

    /// 将 path 转换为坐标数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
