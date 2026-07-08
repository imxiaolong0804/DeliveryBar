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

    private static let accentNSColor = NSColor(named: "AccentColor") ?? .controlAccentColor

    static let accent = Color("AccentColor")
    static let accentWash = Color.dynamic(accentNSColor, lightOpacity: 0.15, darkOpacity: 0.28)

    static let danger = Color(nsColor: .systemRed)
    static let success = Color(nsColor: .systemGreen)

    static let cardBackground = Color.dynamic(
        light: .quaternarySystemFill,
        dark: .white.withAlphaComponent(0.09)
    )
    static let cardStroke = Color.dynamic(
        light: .separatorColor,
        dark: .white.withAlphaComponent(0.14)
    )
    static let quietFill = Color.dynamic(
        light: .quinarySystemFill,
        dark: .white.withAlphaComponent(0.06)
    )
    static var barBackground: Color {
        Color.dynamic(.systemTeal, lightOpacity: 0.08, darkOpacity: 0.16)
    }
    static var footerBackground: Color { barBackground }
    static let selectedBackground = Color.dynamic(accentNSColor, lightOpacity: 0.18, darkOpacity: 0.30)

    static let attentionWash = Color.dynamic(.systemRed, lightOpacity: 0.08, darkOpacity: 0.15)
    static let priorityHighWash = Color.dynamic(.systemRed, lightOpacity: 0.07, darkOpacity: 0.13)
    static let priorityMediumWash = Color.dynamic(accentNSColor, lightOpacity: 0.08, darkOpacity: 0.15)

    @ViewBuilder
    static var panelBackground: some View {
        ZStack {
            // 深色下垫一层近实底，避免黑色桌面透出导致面板发糊；浅色保持全透明
            Color.dynamic(light: .clear, dark: .windowBackgroundColor.withAlphaComponent(0.72))
            LinearGradient(
                colors: [
                    Color.dynamic(.windowBackgroundColor, lightOpacity: 0.74, darkOpacity: 0.82),
                    Color.dynamic(.systemGreen, lightOpacity: 0.08, darkOpacity: 0.14),
                    Color.dynamic(accentNSColor, lightOpacity: 0.07, darkOpacity: 0.12),
                    Color.dynamic(.systemTeal, lightOpacity: 0.12, darkOpacity: 0.18),
                    Color.dynamic(.controlBackgroundColor, lightOpacity: 0.68, darkOpacity: 0.80)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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
        static let icon: CGFloat = 8
        static let panel: CGFloat = 14
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
    }
}

extension Color {
    /// 明暗外观自适应颜色：渲染时按当前外观解析
    static func dynamic(light: @autoclosure @escaping () -> NSColor,
                        dark: @autoclosure @escaping () -> NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark() : light()
        })
    }

    static func dynamic(_ base: NSColor, lightOpacity: CGFloat, darkOpacity: CGFloat) -> Color {
        dynamic(light: base.withAlphaComponent(lightOpacity),
                dark: base.withAlphaComponent(darkOpacity))
    }
}
