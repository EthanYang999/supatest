# 🌍 EarthLord（地球新主）

<p align="center">
  <img src="docs/images/logo.png" alt="EarthLord Logo" width="200">
</p>

<p align="center">
  <strong>在末日世界中行走、圈地、生存</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2016%2B-blue?logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/SwiftUI-5.0-orange?logo=swift" alt="SwiftUI">
  <img src="https://img.shields.io/badge/MapKit-Enabled-green?logo=apple" alt="MapKit">
  <img src="https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase" alt="Supabase">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
</p>

---

## 📖 项目简介

**EarthLord** 是一款基于 LBS（地理位置服务）的 iOS 末日生存游戏。玩家通过真实世界的行走来圈定领地、探索资源点、建造设施，与其他幸存者交易和通讯，在末日废土中建立自己的势力范围。

---

## ✨ 核心功能

| 功能 | 描述 |
|------|------|
| 🗺️ **圈地系统** | GPS 追踪行走路径，闭环即占领土地 |
| 🔍 **探索系统** | 探索真实 POI（医院、超市等）获取物资 |
| 🏗️ **建造系统** | 在领地上建造庇护所、仓库、发电机等设施 |
| 🤝 **交易系统** | 与其他玩家交换物资资源 |
| 📡 **通讯系统** | 无线电频道与附近幸存者联络 |

---

## 🛠️ 技术栈

- **前端框架**: SwiftUI
- **地图服务**: MapKit + Core Location
- **后端服务**: Supabase (PostgreSQL + Auth + Realtime)
- **最低版本**: iOS 16.0+
- **开发工具**: Xcode 15+

---

## 📦 安装说明

### 前置要求

- macOS 14.0+
- Xcode 15.0+
- iOS 16.0+ 设备或模拟器
- Supabase 账号

### 安装步骤

```bash
# 1. 克隆项目
git clone https://github.com/[your-username]/EarthLord.git

# 2. 进入项目目录
cd EarthLord

# 3. 用 Xcode 打开项目
open EarthLord.xcodeproj
```

### 配置 Supabase

1. 在 [Supabase](https://supabase.com) 创建新项目
2. 复制 `Config.example.swift` 为 `Config.swift`
3. 填入你的 Supabase URL 和 API Key

```swift
struct Config {
    static let supabaseURL = "your-project-url"
    static let supabaseKey = "your-anon-key"
}
```

---

## 📁 项目结构

```
EarthLord/
├── EarthLordApp.swift        # App 入口
├── Config.swift              # 配置文件（gitignore）
├── Theme/
│   └── ApocalypseTheme.swift # 末日风格主题
├── Models/
│   ├── Player.swift          # 玩家模型
│   ├── Territory.swift       # 领地模型
│   └── Item.swift            # 物品模型
├── Views/
│   ├── ContentView.swift     # 主 TabView
│   └── Tabs/
│       ├── MapTabView.swift          # 地图页
│       ├── TerritoryTabView.swift    # 领地页
│       ├── ResourcesTabView.swift    # 资源页
│       ├── ProfileTabView.swift      # 个人页
│       └── CommunicationTabView.swift# 通讯页
├── Services/
│   ├── LocationManager.swift # 定位服务
│   └── SupabaseManager.swift # 后端服务
└── Utils/
    └── Extensions.swift      # 扩展工具
```

---

## 📈 开发进度

### 里程碑 1：核心基础
- [x] 项目初始化
- [x] 基础 UI 框架（TabView）
- [x] 末日主题配色
- [ ] Supabase 配置
- [ ] 用户认证
- [ ] 地图基础展示
- [ ] GPS 路径记录
- [ ] 闭环检测
- [ ] 领地创建与存储

### 里程碑 2：资源与建造
- [ ] POI 发现与展示
- [ ] POI 探索交互
- [ ] 背包系统
- [ ] 建筑系统

### 里程碑 3：社交互动
- [ ] 玩家领地展示
- [ ] 交易系统
- [ ] 通讯系统

### 里程碑 4：优化发布
- [ ] 性能优化
- [ ] 新手引导
- [ ] App Store 提交

---

## 👨‍💻 开发者

**[学员名字]**

📚 AI Vibe Coding 60天训练营学员作品

---

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

---

<p align="center">
  <sub>🎮 在废土中行走，成为地球的新主人</sub>
</p>
