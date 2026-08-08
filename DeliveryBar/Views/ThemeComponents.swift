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

/// 窗口工具栏按钮：只有图标，悬停才出底色，选中态走强调色。
/// 取代原先工具栏里的 Toggle(.switch) 和 .bordered 图文按钮——那两种在标题栏里
/// 视觉重量太大，一排下来就是一条控件墙。
struct ChromeButton: View {
    let systemImage: String
    var isActive = false
    var shortcut: KeyEquivalent?
    var modifiers: EventModifiers = .command
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        if let shortcut {
            button.keyboardShortcut(shortcut, modifiers: modifiers)
        } else {
            button
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(isActive ? DeliveryBarTheme.accent : DeliveryBarTheme.softText)
                .frame(width: 24, height: 24)
                .background { chromeBackground }
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .help(help)
        .accessibilityLabel(help)
    }

    /// 选中态走 Liquid Glass：面板本身就是一层毛玻璃，选中按钮再盖一块不透明强调色
    /// 会像贴上去的贴纸；玻璃叠玻璃能透出底下的桌面色，和面板是同一种材质语言。
    @ViewBuilder
    private var chromeBackground: some View {
        if isActive {
            Color.clear
                .glassEffect(
                    .regular.tint(DeliveryBarTheme.accent.opacity(0.28)),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(isHovered ? 0.07 : 0))
        }
    }
}

/// 列表行的删除按钮：平时隐藏，悬停行时显示；点击后原位展开「取消 / 删除」二次确认
struct RowDeleteButton: View {
    let isRowHovered: Bool
    @Binding var isConfirming: Bool
    let onDelete: () -> Void

    var body: some View {
        Group {
            if isConfirming {
                HStack(spacing: 6) {
                    Button("取消") {
                        withAnimation(.snappy(duration: 0.16)) {
                            isConfirming = false
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(DeliveryBarTheme.softText)

                    Button("删除") {
                        onDelete()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(DeliveryBarTheme.danger)
                }
                .font(DeliveryBarTheme.Typography.caption)
            } else {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        isConfirming = true
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(DeliveryBarTheme.Typography.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(DeliveryBarTheme.softText)
                .help("删除")
            }
        }
        .opacity(isRowHovered || isConfirming ? 1 : 0)
        .allowsHitTesting(isRowHovered || isConfirming)
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
