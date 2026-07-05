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

    static let accent = Color("AccentColor")
    static let accentWash = accent.opacity(0.15)

    static let danger = Color(nsColor: .systemRed)
    static let success = Color(nsColor: .systemGreen)

    static let cardBackground = Color(nsColor: .quaternarySystemFill)
    static let cardStroke = Color(nsColor: .separatorColor)
    static let footerBackground = Color(nsColor: .quinarySystemFill)
    static let selectedBackground = accent.opacity(0.18)

    static var panelBackground: Color { .clear }

    static func pillBackground(isSelected: Bool) -> Color {
        isSelected ? selectedBackground : Color(nsColor: .quinarySystemFill)
    }

    static func pillStroke(isSelected: Bool) -> Color {
        isSelected ? accent.opacity(0.35) : Color(nsColor: .separatorColor)
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
