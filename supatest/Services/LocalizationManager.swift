//
//  LocalizationManager.swift
//  supatest
//
//  EarthLord 游戏语言管理器
//  负责处理应用内语言切换，支持跟随系统、简体中文、English
//

import Foundation
import SwiftUI
import Combine

// MARK: - 语言选项枚举

/// 用户可选择的语言选项
enum LanguageOption: String, CaseIterable, Identifiable {
    case system = "system"           // 跟随系统
    case english = "en"              // English
    case simplifiedChinese = "zh-Hans"  // 简体中文

    var id: String { rawValue }

    /// 显示名称（本地化）
    var displayName: LocalizedStringKey {
        switch self {
        case .system:
            return "跟随系统"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    /// 副标题说明
    var subtitle: String {
        switch self {
        case .system:
            return "Follow System"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Chinese Simplified"
        }
    }

    /// 国旗表情
    var flag: String {
        switch self {
        case .system:
            return "🌐"
        case .english:
            return "🇺🇸"
        case .simplifiedChinese:
            return "🇨🇳"
        }
    }

    /// 获取实际的语言代码（用于 Bundle）
    var languageCode: String {
        switch self {
        case .system:
            // 获取系统语言
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            if systemLanguage.hasPrefix("zh") {
                return "zh-Hans"
            }
            return "en"
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }
}

// MARK: - 语言管理器

/// 语言管理器 - 单例模式
/// 负责管理应用内语言切换，支持跟随系统、简体中文、English
@MainActor
class LocalizationManager: ObservableObject {

    // MARK: - 单例

    static let shared = LocalizationManager()

    // MARK: - 存储键

    private let languageKey = "app_language_option"

    // MARK: - 发布属性

    /// 用户选择的语言选项
    @Published var selectedOption: LanguageOption {
        didSet {
            guard oldValue != selectedOption else { return }
            UserDefaults.standard.set(selectedOption.rawValue, forKey: languageKey)
            applyLanguage()
            // 触发 UI 刷新
            refreshID = UUID()
        }
    }

    /// 用于强制刷新 UI 的 ID
    @Published var refreshID = UUID()

    /// 当前实际使用的语言代码
    var currentLanguageCode: String {
        selectedOption.languageCode
    }

    /// 当前语言的 Bundle
    var currentBundle: Bundle {
        guard let path = Bundle.main.path(forResource: currentLanguageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }

    // MARK: - 初始化

    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedOption = UserDefaults.standard.string(forKey: languageKey),
           let option = LanguageOption(rawValue: savedOption) {
            self.selectedOption = option
        } else {
            // 默认跟随系统
            self.selectedOption = .system
        }

        applyLanguage()
    }

    // MARK: - 公开方法

    /// 设置语言选项
    /// - Parameter option: 目标语言选项
    func setLanguage(_ option: LanguageOption) {
        guard selectedOption != option else { return }
        selectedOption = option
        print("🌐 语言已切换至: \(option.subtitle)")
    }

    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 字符串键
    ///   - comment: 注释
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: currentBundle, comment: comment)
    }

    /// 当前显示的语言名称（用于设置页面显示）
    var currentLanguageDisplayName: String {
        switch selectedOption {
        case .system:
            // 显示 "跟随系统" 加上实际语言
            let actualLanguage = currentLanguageCode == "zh-Hans" ? "中文" : "English"
            return "跟随系统 (\(actualLanguage))"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    // MARK: - 私有方法

    private func applyLanguage() {
        // 设置 AppleLanguages 以影响系统组件（如日期选择器等）
        UserDefaults.standard.set([currentLanguageCode], forKey: "AppleLanguages")
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

// MARK: - 本地化 Text 扩展

extension Text {
    /// 使用当前语言 Bundle 的本地化 Text
    init(localized key: String) {
        self.init(NSLocalizedString(key, bundle: LocalizationManager.shared.currentBundle, comment: ""))
    }
}

// MARK: - 环境值扩展

private struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localizationManager: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
}
