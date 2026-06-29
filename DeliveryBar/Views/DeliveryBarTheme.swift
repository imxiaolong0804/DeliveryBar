//
//  DeliveryBarTheme.swift
//  DeliveryBar
//

import SwiftUI

enum DeliveryBarTheme {
    static let appName = "DeliveryBar"
    static let ink = Color(red: 0.18, green: 0.19, blue: 0.20)
    static let inkSoft = Color(red: 0.36, green: 0.37, blue: 0.36)
    static let accent = Color(red: 0.92, green: 0.69, blue: 0.16)
    static let accentSoft = Color(red: 0.98, green: 0.84, blue: 0.34)
    static let accentWash = Color(red: 0.99, green: 0.90, blue: 0.58)
    static let panelTop = Color(red: 0.995, green: 0.985, blue: 0.95)
    static let panelBottom = Color(red: 0.94, green: 0.965, blue: 0.935)
    static let cardBackground = Color(red: 1.00, green: 0.985, blue: 0.94).opacity(0.86)
    static let cardStroke = ink.opacity(0.10)
    static let footerBackground = Color.white.opacity(0.42)
    static let selectedBackground = accentWash.opacity(0.36)
    static let softText = inkSoft.opacity(0.86)
    static let danger = Color(red: 0.74, green: 0.26, blue: 0.22)
    static let success = Color(red: 0.38, green: 0.55, blue: 0.42)
    static let muted = Color(red: 0.48, green: 0.49, blue: 0.47)

    static var panelBackground: LinearGradient {
        LinearGradient(
            colors: [panelTop, panelBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func pillBackground(isSelected: Bool) -> Color {
        isSelected ? selectedBackground : Color.white.opacity(0.30)
    }

    static func pillStroke(isSelected: Bool) -> Color {
        isSelected ? accent.opacity(0.34) : cardStroke
    }

    static func pillForeground(isSelected: Bool) -> Color {
        isSelected ? ink : softText
    }
}
