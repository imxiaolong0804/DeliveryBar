//
//  ThemeComponents.swift
//  DeliveryBar
//

import SwiftUI

private struct HoverHighlightModifier: ViewModifier {
    let cornerRadius: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
                    .allowsHitTesting(false)
            }
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }
    }
}

private struct SelectablePillModifier: ViewModifier {
    let isSelected: Bool
    let tint: Color?
    let verticalPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(background, in: RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.pill, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.pill, style: .continuous)
                    .stroke(stroke)
            }
            .hoverHighlight(cornerRadius: DeliveryBarTheme.Radius.pill)
    }

    private var background: Color {
        guard let tint else {
            return DeliveryBarTheme.pillBackground(isSelected: isSelected)
        }
        return isSelected ? tint.opacity(0.18) : DeliveryBarTheme.cardBackground
    }

    private var stroke: Color {
        guard let tint else {
            return DeliveryBarTheme.pillStroke(isSelected: isSelected)
        }
        return tint.opacity(isSelected ? 0.55 : 0.24)
    }
}

private struct DeliveryCardModifier: ViewModifier {
    let padding: EdgeInsets
    let stroke: Color
    let background: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background, in: RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous)
                    .stroke(stroke)
            }
    }
}

extension View {
    func hoverHighlight(cornerRadius: CGFloat = DeliveryBarTheme.Radius.card) -> some View {
        modifier(HoverHighlightModifier(cornerRadius: cornerRadius))
    }

    func selectablePill(
        isSelected: Bool,
        tint: Color? = nil,
        verticalPadding: CGFloat
    ) -> some View {
        modifier(SelectablePillModifier(isSelected: isSelected, tint: tint, verticalPadding: verticalPadding))
    }

    func deliveryCard(
        padding: CGFloat,
        stroke: Color = DeliveryBarTheme.cardStroke,
        background: Color = DeliveryBarTheme.cardBackground
    ) -> some View {
        deliveryCard(
            padding: EdgeInsets(top: padding, leading: padding, bottom: padding, trailing: padding),
            stroke: stroke,
            background: background
        )
    }

    func deliveryCard(
        padding: EdgeInsets,
        stroke: Color = DeliveryBarTheme.cardStroke,
        background: Color = DeliveryBarTheme.cardBackground
    ) -> some View {
        modifier(DeliveryCardModifier(padding: padding, stroke: stroke, background: background))
    }
}
