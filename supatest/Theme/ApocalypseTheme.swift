//
//  ApocalypseTheme.swift
//  supatest
//
//  EarthLord Game - Apocalypse Theme Colors
//

import SwiftUI

enum ApocalypseTheme {
    // MARK: - Primary Colors

    /// 主色：橙色 #FF6B35
    static let primary = Color(hex: "FF6B35")

    /// 背景：深灰 #1A1A2E
    static let background = Color(hex: "1A1A2E")

    /// 文字：浅灰 #E8E8E8
    static let text = Color(hex: "E8E8E8")

    // MARK: - Secondary Colors

    /// 次要文字颜色
    static let secondaryText = Color(hex: "A0A0A0")

    /// 次要文字颜色（别名）
    static let textSecondary = secondaryText

    /// 卡片背景
    static let cardBackground = Color(hex: "2A2A3E")

    /// 分割线
    static let separator = Color(hex: "3A3A4E")

    // MARK: - Status Colors

    /// 成功色：绿色
    static let success = Color(hex: "4CAF50")

    /// 危险色：红色
    static let danger = Color(hex: "E53935")

    /// 警告色：黄色
    static let warning = Color(hex: "FFC107")
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - UIColor Extension for UIKit Components

extension UIColor {
    static let apocalypsePrimary = UIColor(red: 255/255, green: 107/255, blue: 53/255, alpha: 1)
    static let apocalypseBackground = UIColor(red: 26/255, green: 26/255, blue: 46/255, alpha: 1)
    static let apocalypseText = UIColor(red: 232/255, green: 232/255, blue: 232/255, alpha: 1)
}
