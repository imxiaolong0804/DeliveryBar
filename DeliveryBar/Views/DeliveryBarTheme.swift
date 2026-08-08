//
//  DeliveryBarTheme.swift
//  DeliveryBar
//

import AppKit
import SwiftUI

enum DeliveryBarTheme {
    static let appName = "DeliveryBar"
    static let ink = Color.primary
    static let inkSoft = Color.secondary
    static let softText = Color.secondary
    static let muted = Color(nsColor: .tertiaryLabelColor)

    /// 跟随系统强调色（系统设置里用户选什么就是什么）
    private static let accentNSColor = NSColor.controlAccentColor

    static let accent = Color(nsColor: .controlAccentColor)

    static let danger = Color(nsColor: .systemRed)
    static let success = Color(nsColor: .systemGreen)

    static let cardBackground = Color.dynamic(
        light: .quaternarySystemFill,
        dark: .white.withAlphaComponent(0.07)
    )
    static let cardStroke = Color.dynamic(
        light: .separatorColor,
        dark: .white.withAlphaComponent(0.12)
    )
    static let quietFill = Color.dynamic(
        light: .quinarySystemFill,
        dark: .white.withAlphaComponent(0.05)
    )
    static let selectedBackground = Color.dynamic(accentNSColor, lightOpacity: 0.16, darkOpacity: 0.30)

    /// 面板底色：浅色直接透出系统毛玻璃；深色垫一层中性底，避免黑色桌面透出导致内容发糊
    static var panelBackground: some View {
        Color.dynamic(light: .clear, dark: .windowBackgroundColor.withAlphaComponent(0.55))
    }

    static func pillBackground(isSelected: Bool) -> Color {
        isSelected ? selectedBackground : quietFill
    }

    static func pillStroke(isSelected: Bool) -> Color {
        isSelected ? Color.dynamic(accentNSColor, lightOpacity: 0.35, darkOpacity: 0.50) : cardStroke
    }

    static func pillForeground(isSelected: Bool) -> Color {
        isSelected ? .primary : .secondary
    }

    enum Radius {
        static let pill: CGFloat = 8
        static let card: CGFloat = 8
        static let panel: CGFloat = 14
    }

    /// 五档字号，字重只有 regular 和 medium。
    ///
    /// 不再用 .caption / .caption2 / .subheadline 这些语义字号：在 macOS 上
    /// .caption、.caption2、.footnote 全都是 10pt，.subheadline 是 11pt——
    /// 代码里在 caption 和 caption2 之间反复切换，看着像分了层级，渲染出来一模一样，
    /// 只剩下"糊"。名字按用途取，避免再按感觉挑。
    enum Typography {
        /// 15 medium — 可编辑的文档标题（备忘标题）
        static let documentTitle = Font.system(size: 15, weight: .medium)
        /// 14 medium — 窗口标题栏
        static let windowTitle = Font.system(size: 14, weight: .medium)
        /// 13 medium — 列表行标题
        static let rowTitle = Font.system(size: 13, weight: .medium)
        /// 13 — 正文
        static let body = Font.system(size: 13)
        /// 12 — 次要文字、输入框
        static let callout = Font.system(size: 12)
        /// 11 — 时间戳、元信息。11 是下限，不要再往下走
        static let caption = Font.system(size: 11)
        /// 11 medium — 区块小标题
        static let captionStrong = Font.system(size: 11, weight: .medium)
        /// 12 等宽 — JSON、代码、值
        static let mono = Font.system(size: 12, design: .monospaced)
        /// 12 等宽 medium — 需要强调的等宽内容，比如差异列表里的字段路径
        static let monoStrong = Font.system(size: 12, weight: .medium, design: .monospaced)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }
}

extension NSColor {
    /// 明暗外观自适应颜色：绘制时才按当前外观解析。
    /// 存进 NSTextStorage 的着色用它，明暗切换就不用重新跑一遍高亮。
    static func dynamic(light: @autoclosure @escaping () -> NSColor,
                        dark: @autoclosure @escaping () -> NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark() : light()
        }
    }

    /// 十六进制字面量，只给两个语法高亮主题用
    static func hex(_ value: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    /// 明暗外观自适应颜色：渲染时按当前外观解析
    static func dynamic(light: @autoclosure @escaping () -> NSColor,
                        dark: @autoclosure @escaping () -> NSColor) -> Color {
        Color(nsColor: .dynamic(light: light(), dark: dark()))
    }

    static func dynamic(_ base: NSColor, lightOpacity: CGFloat, darkOpacity: CGFloat) -> Color {
        dynamic(light: base.withAlphaComponent(lightOpacity),
                dark: base.withAlphaComponent(darkOpacity))
    }
}
