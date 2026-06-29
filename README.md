<div align="center">

<img src="DeliveryBar/Assets.xcassets/AppIcon.appiconset/AppIcon-512x512@2x.png" alt="DeliveryBar Icon" width="128" height="128" />

# DeliveryBar

**轻量级 macOS 菜单栏需求交付追踪工具**

*Write code. Ship it. Never forget to deliver again.*

[![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-lightgrey?logo=apple)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-5.0-FA7343?logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-007AFF?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)

</div>

---

## 📖 这是什么？

**DeliveryBar** 是一个驻留在 macOS 菜单栏的个人需求管理工具，专为同时处理多个需求的开发者设计。

它解决一个常见但容易被忽视的问题：**代码写完了，却忘了交付**。

日常开发中，一个开发者经常同时维护多个需求分支——开发完成、等待联调、已提测、待验收、准备上线……状态多且分散在 Jira、文档、聊天记录里。DeliveryBar 把这些信息收拢到菜单栏，让你一眼看清每条需求现在处于什么阶段、有没有被遗忘。

<div align="center">
  <img src="screenshots/main-panel.png" alt="主面板截图" width="420" />
  <p><em>（截图示例——请替换为实际截图）</em></p>
</div>

## ✨ 功能

- 🖥️ **菜单栏常驻** — 点击图标即可展开面板，不占用 Dock 空间
- 📋 **需求全生命周期管理** — 覆盖 `待开发 → 开发中 → 已开发未交付 → 待验收 → 已完成 → 已归档` 六个阶段
- ⏰ **智能超时提醒** — 需求停滞过久或超过截止日期时，菜单栏图标显示角标，列表中展示醒目提示
- 📦 **一键归档** — 已完成的需求归档不扰，历史数据随时可查
- 🔖 **临时任务** — 7 天滚动日历视图，记录日常杂项（查 case、联调、问题备注）
- 🎨 **精心设计的视觉系统** — 暖色调配色，状态色一目了然
- 🔒 **100% 本地存储** — 基于 SwiftData，无网络请求、无账号系统、无第三方追踪
- 🪶 **零外部依赖** — 纯 Apple 原生框架，不引入任何第三方库

## 🚀 快速开始

### 环境要求

| 项目 | 要求 |
|------|------|
| macOS | 14.0+ |
| Xcode | 15.0+ |
| Swift | 5.0 |

### 克隆 & 构建

```bash
# 克隆仓库
git clone https://github.com/your-username/DeliveryBar.git
cd DeliveryBar

# 用 Xcode 打开
open DeliveryBar.xcodeproj
```

然后在 Xcode 中按 `⌘ + R` 运行，或使用命令行构建：

```bash
xcodebuild -project DeliveryBar.xcodeproj \
  -scheme DeliveryBar \
  -configuration Release \
  build
```

### 打包 DMG

```bash
./scripts/package_dmg.sh 1.0.1
```

生成的 `.dmg` 文件位于 `dist/` 目录。

### 重新生成 App 图标

```bash
swift scripts/generate_app_icon.swift
```

图标由纯代码绘制（`NSBezierPath`），无外部设计文件依赖。

## 🧭 使用指南

### 需求状态流转

```
待开发 → 开发中 → 已开发未交付 → 待验收 → 已完成 → 已归档
```

每条需求卡片上可以直接切换状态——点击状态旁的展开箭头，选择目标状态即可，无需进入编辑页。

### 超时提醒规则

| 状态 | 触发条件 | 提示文案示例 |
|------|----------|-------------|
| 开发中 | 超过 7 天未推进 |「7 天未推进」|
| 已开发未交付 | 超过 5 天未交付 |「5 天未交付」|
| 待验收 | 超过 5 天未验收 |「5 天未验收」|
| 任意 | 超过截止日期 |「已逾期 N 天」|

提醒为轻量级——仅限菜单栏角标和列表内文案高亮。单条需求可临时静音提醒（「稍后提醒」），全局可在设置中关闭。

### 临时任务

适合「不属于某个需求但又得记一笔」的场景：

- 📌 查 case
- 🔗 联调对接
- 🐛 issue 跟进
- ✏️ 自定义类型

以 7 天为窗口，滚动展示每日任务列表。过期任务自动清理，无需手动删除。

## 🏗️ 项目结构

```
DeliveryBar/
├── DeliveryBarApp.swift              # 应用入口（MenuBarExtra）
├── Models/
│   ├── Requirement.swift             # 核心数据模型（需求、状态枚举）
│   ├── PersonProfile.swift           # PM/QA 联系人档案
│   └── TemporaryTask.swift           # 临时任务模型
├── Views/
│   ├── DeliveryBarTheme.swift        # 设计系统（颜色、渐变、组件样式）
│   ├── MenuBarView.swift             # 主面板（状态 Tab 切换）
│   ├── MenuBarLabelView.swift        # 菜单栏图标与角标
│   ├── RequirementRowView.swift      # 需求卡片组件
│   ├── RequirementEditorView.swift   # 需求新增/编辑表单
│   ├── TemporaryTasksView.swift      # 临时任务 7 天滚动视图
│   └── SettingsView.swift            # 设置页
├── Services/
│   └── ReminderService.swift         # 超时判断与提醒逻辑
├── Utils/
│   └── DateUtils.swift               # 日期格式化工具
├── Assets.xcassets/                  # App 图标、强调色
├── scripts/
│   ├── package_dmg.sh                # DMG 打包脚本
│   └── generate_app_icon.swift       # 图标代码生成器
└── dist/                             # 构建产物
```

## 🛠️ 技术栈

| 模块 | 技术 |
|------|------|
| UI | SwiftUI |
| 菜单栏 | `MenuBarExtra`（`.window` 样式） |
| 持久化 | SwiftData |
| 通知 | `UserNotifications`（规划中） |
| 构建 | `xcodebuild` + `hdiutil` |

**零外部依赖**——项目不引入任何 Swift Package 或 CocoaPod。所有能力均由 Apple 原生框架提供，构建极其轻量。

## 🗺️ 路线图

- [x] **V1.0** — 核心状态管理、菜单栏常驻、超时提示、SwiftData 持久化
- [x] **V1.1** — 临时任务模块、联系人档案、视觉优化
- [ ] **V1.2** — 系统本地通知、开机自启动、搜索筛选
- [ ] **V2.0** — Git 分支绑定、Jira/Tapd 同步、日报自动生成

详见 [prd.md](prd.md)。

## 🤝 贡献

欢迎提 Issue 和 PR。

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feat/amazing-feature`
3. 提交更改：`git commit -m 'feat: add amazing feature'`
4. 推送到远程：`git push origin feat/amazing-feature`
5. 提交 Pull Request

## 📄 许可

MIT License — 详见 [LICENSE](LICENSE)。

---

<div align="center">

**Made with ❤️ for developers who ship.**

如果 DeliveryBar 帮到了你，请给个 ⭐ Star！

</div>