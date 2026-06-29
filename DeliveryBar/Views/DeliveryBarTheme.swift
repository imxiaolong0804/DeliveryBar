//
//  DeliveryBarTheme.swift
//  DeliveryBar
//

import SwiftUI

enum DeliveryBarTheme {
    static let appName = "DeliveryBar"
    static let accent = Color(red: 0.20, green: 0.38, blue: 0.82)
    static let panelTop = Color(red: 0.97, green: 0.98, blue: 1.00)
    static let panelBottom = Color(red: 0.94, green: 0.96, blue: 0.99)
    static let cardBackground = Color.white.opacity(0.68)
    static let cardStroke = Color.black.opacity(0.06)
    static let softText = Color.secondary.opacity(0.88)

    static var panelBackground: LinearGradient {
        LinearGradient(
            colors: [panelTop, panelBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
