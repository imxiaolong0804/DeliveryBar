<div align="center">

<img src="DeliveryBar/Assets.xcassets/AppIcon.appiconset/AppIcon-512x512@2x.png" alt="DeliveryBar Icon" width="128" height="128" />

# DeliveryBar

**轻量级 macOS 菜单栏需求交付追踪与开发辅助工具**

*Write code. Ship it. Never forget to deliver again.*

[![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-lightgrey?logo=apple)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-5.0-FA7343?logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-007AFF?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)

</div>

---

## 📖 这是什么？

**DeliveryBar** 是一个驻留在 macOS 菜单栏的个人需求管理与开发辅助工具，专为同时处理多个需求的开发者设计。

它解决一个常见但容易被忽视的问题：**代码写完了，却忘了交付**。

日常开发中，一个开发者经常同时维护多个需求分支——待开发、开发中、已提测、测试中、准备上线……状态多且分散在 Jira、文档、聊天记录里。DeliveryBar 把这些信息收拢到菜单栏，让你一眼看清每条需求现在处于什么阶段、有没有被遗忘。

<div align="center">
  <img src="example.png" alt="主面板截图" width="420" />
</div>

## ✨ 功能

- 🖥️ **菜单栏常驻** — 基于 `NSStatusItem` 常驻菜单栏，不占用 Dock 空间
- ⌨️ **全局快捷键** — `⌘⇧D` 快速显示/隐藏主面板，`⌘⇧J` 快速打开 JSON 工具
- 📋 **需求全生命周期管理** — 覆盖 `待开发 → 正在开发 → 测试中 → 待上线 → 已完成` 主流程
- ⏰ **智能超时提醒** — 需求停滞过久或超过截止日期时，菜单栏图标显示角标，列表中展示醒目提示
- 📦 **一键归档** — 已完成的需求归档不扰，历史数据随时可查
- 🔖 **临时任务** — 7 天滚动日历视图，待办事项 + 工作日志双分区，待办可勾选完成，日志便于写日报
- ⌨️ **快捷录** — 保存常用链接、脚本和文本片段，按 key 快速检索，一键打开链接或复制内容
- 🧩 **JSON 格式化工具** — 独立窗口格式化、压缩、复制、搜索 JSON，保留输入 key 顺序，支持最近 50 条历史
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

然后在 Xcode 中按 `⌘ + R` 运行。应用不会显示 Dock 图标，启动后会出现在菜单栏；如果系统符号不可用，会显示 `DB` 作为兜底入口。

也可以使用命令行构建：

```bash
xcodebuild -project DeliveryBar.xcodeproj \
  -scheme DeliveryBar \
  -configuration Release \
  build
```

### 打包 DMG

```bash
./scripts/package_dmg.sh 1.0.2
```

生成的 `.dmg` 文件位于 `dist/` 目录。

### 重新生成 App 图标

```bash
swift scripts/generate_app_icon.swift
```

图标由纯代码绘制（`NSBezierPath`），无外部设计文件依赖。

## 🧭 使用指南

### 快捷呼出

| 快捷键 | 功能 |
|--------|------|
| `⌘⇧D` | 显示/隐藏主面板 |
| `⌘⇧J` | 打开 JSON 格式化窗口 |

快捷键使用系统原生 `RegisterEventHotKey` 注册。如果快捷键被其他应用占用，设置页会展示注册失败状态。

### 需求状态流转

```
待开发 → 正在开发 → 测试中 → 待上线 → 已完成
```

每条需求卡片上可以直接切换状态——点击状态旁的展开箭头，选择目标状态即可，无需进入编辑页。

`已开发，未交付` 是历史兼容状态，应用启动时会自动迁移到 `测试中`。`归档` 是完成后的收纳动作，不作为主流程阶段展示。

### 超时提醒规则

| 状态 | 触发条件 | 提示文案示例 |
|------|----------|-------------|
| 正在开发 | 超过 7 天未推进 |「7 天未推进」|
| 测试中 | 超过 5 天未处理 |「5 天测试中」|
| 待上线 | 超过 5 天未处理 |「5 天待上线」|
| 任意 | 超过截止日期 |「已逾期 N 天」|

提醒为轻量级——仅限菜单栏角标和列表内文案高亮。单条需求可临时静音提醒（「稍后提醒」），全局可在设置中关闭。

### 临时任务

适合「不属于某个需求但又得记一笔」的场景，分为两类：

- ✅ **待办** — 当天要完成的事项，可勾选完成状态
- 📝 **日志** — 记录当天的事情，方便写日报

以 7 天为窗口，滚动展示每日任务列表。过期任务自动清理，无需手动删除。

### 快捷录

保存常用的链接、脚本和文本片段，通过自定义 key 快速检索：

- 🔗 **链接** — 一键在浏览器中打开
- 💻 **脚本** — 一键复制到剪贴板
- 📄 **文本** — 常用文本片段，一键复制

支持按类型筛选、关键词搜索，高频条目自动靠前。

### JSON 格式化

JSON 工具可以从主面板底部的「JSON 格式化」按钮打开，也可以按 `⌘⇧J` 直接打开。

- **格式化** — 按 2 空格缩进输出，保留输入 JSON object 的 key 顺序
- **压缩** — 去掉多余空白，仍然保留 key 顺序
- **搜索** — 可在输入区或结果区搜索内容，并跳转到匹配位置
- **区域调整** — 拖动输入区和结果区中间的分隔条，调整两边显示比例；比例会自动保存
- **历史记录** — 格式化成功后保存到本地 SwiftData，最多保留最近 50 条
- **临时草稿** — 输入内容会保存 1 分钟，短时间内重开窗口可恢复；超过 1 分钟后清空
- **置顶** — 默认切换到其他应用时自动隐藏；打开「置顶」后窗口保持显示

JSON 解析使用项目内置的保序 parser，不依赖 `JSONSerialization` 重新排序 object key。非法 JSON 会显示行列错误，不会覆盖输入，也不会写入历史。

## 🏗️ 项目结构

```
DeliveryBar/
├── DeliveryBarApp.swift              # AppKit 应用入口，初始化 SwiftData、状态栏和快捷键
├── Models/
│   ├── Requirement.swift             # 核心数据模型（需求、状态枚举）
│   ├── PersonProfile.swift           # PM/QA 联系人档案
│   ├── TemporaryTask.swift           # 临时任务模型（待办/日志）
│   ├── QuickEntry.swift              # 快捷录模型（链接/脚本/文本）
│   └── JSONFormatHistory.swift       # JSON 格式化历史记录
├── Views/
│   ├── DeliveryBarTheme.swift        # 设计系统（颜色、渐变、组件样式）
│   ├── MenuBarView.swift             # 主面板（状态 Tab 切换）
│   ├── RequirementRowView.swift      # 需求卡片组件
│   ├── RequirementEditorView.swift   # 需求新增/编辑表单
│   ├── TemporaryTasksView.swift      # 临时任务 7 天滚动视图
│   ├── QuickEntryListView.swift      # 快捷录列表视图
│   ├── QuickEntryEditorView.swift    # 快捷录新增/编辑表单
│   ├── JSONFormatterView.swift       # JSON 格式化、压缩、搜索、历史 UI
│   └── SettingsView.swift            # 设置页
├── Services/
│   ├── StatusBarController.swift     # NSStatusItem 菜单栏入口
│   ├── FloatingPanelController.swift # 主面板和 JSON 浮动面板管理
│   ├── HotKeyService.swift           # 全局快捷键注册
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
| 菜单栏 | `NSStatusItem` |
| 浮动窗口 | `NSPanel` + `NSHostingController` |
| 快捷键 | Carbon `RegisterEventHotKey` |
| 持久化 | SwiftData |
| JSON | 自定义保序 parser + renderer |
| 提醒 | 本地状态判断 + 菜单栏角标 |
| 构建 | `xcodebuild` + `hdiutil` |

**零外部依赖**——项目不引入任何 Swift Package 或 CocoaPod。所有能力均由 Apple 原生框架提供，构建极其轻量。

## 🗺️ 路线图

- [x] **V1.0** — 核心状态管理、菜单栏常驻、超时提示、SwiftData 持久化
- [x] **V1.1** — 临时任务模块、联系人档案、视觉优化
- [x] **V1.2** — 快捷录模块、临时任务拆分待办/日志、面板动态高度、搜索筛选
- [x] **V1.3** — 全局快捷键、`NSStatusItem` 面板、JSON 格式化工具
- [ ] **V1.4** — 系统本地通知、开机自启动
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
