//
//  LocalizationManager.swift
//  supatest
//
//  EarthLord 游戏语言管理器
//  负责处理应用内语言切换
//

import Foundation
import SwiftUI
import Combine

// MARK: - 支持的语言枚举

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    /// 显示名称（用于设置页面）
    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    /// 原生名称
    var nativeName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "中文"
        }
    }

    /// 国旗表情
    var flag: String {
        switch self {
        case .english:
            return "🇺🇸"
        case .simplifiedChinese:
            return "🇨🇳"
        }
    }
}

// MARK: - 语言管理器

@MainActor
class LocalizationManager: ObservableObject {

    // MARK: - 单例

    static let shared = LocalizationManager()

    // MARK: - 存储键

    private let languageKey = "app_language"

    // MARK: - 发布属性

    /// 当前语言
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            applyLanguage()
        }
    }

    // MARK: - 初始化

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // 默认使用系统语言或简体中文
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "zh"
            if systemLanguage.hasPrefix("zh") {
                self.currentLanguage = .simplifiedChinese
            } else {
                self.currentLanguage = .english
            }
        }

        applyLanguage()
    }

    // MARK: - 公开方法

    /// 设置语言
    /// - Parameter language: 目标语言
    func setLanguage(_ language: AppLanguage) {
        guard currentLanguage != language else { return }
        currentLanguage = language
        print("🌐 语言已切换至: \(language.displayName)")
    }

    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 字符串键
    ///   - comment: 注释
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String, comment: String = "") -> String {
        // 获取对应语言的 Bundle
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: comment)
        }
        return NSLocalizedString(key, bundle: bundle, comment: comment)
    }

    // MARK: - 私有方法

    private func applyLanguage() {
        // 设置 AppleLanguages 以影响系统组件
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
}

// MARK: - 便捷扩展

extension String {
    /// 本地化字符串
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }

    /// 带参数的本地化字符串
    func localized(with arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.localizedString(self)
        return String(format: format, arguments: arguments)
    }
}
