//
//  ListComponents.swift
//  DeliveryBar
//
//  列表场景的共享组件：删除二次确认、紧凑任务行、最近 7 天日期条。
//

import SwiftUI

/// 卡片式行的删除二次确认条，展开在卡片下方
struct DeleteConfirmationStrip: View {
    var message = "确认删除？"
    var leadingInset: CGFloat = 12
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DeliveryBarTheme.danger)

            Text(message)
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            Spacer()

            Button("取消", action: onCancel)
                .font(DeliveryBarTheme.Typography.caption)

            Button("删除", role: .destructive, action: onConfirm)
                .font(DeliveryBarTheme.Typography.caption)
        }
        .buttonStyle(.borderless)
        .padding(.leading, leadingInset)
    }
}

/// 待办与日志共用的紧凑行：悬停高亮、悬停才出现的删除按钮、右键复制。
/// 行首元素（勾选框 / 时间）和正文由调用方提供。
struct CompactTaskRow<Leading: View, Content: View>: View {
    let copyText: String
    let onDelete: () -> Void
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false
    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            leading()

            VStack(alignment: .leading, spacing: 3) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)

            RowDeleteButton(
                isRowHovered: isHovered,
                isConfirming: $isConfirmingDelete,
                onDelete: onDelete
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous)
                .fill(Color.primary.opacity(isHovered ? 0.05 : 0))
        )
        .contextMenu {
            Button("复制内容") { Clipboard.copy(copyText) }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
                if !hovering {
                    isConfirmingDelete = false
                }
            }
        }
    }
}

/// 最近 7 天（含今天）的日期选择条
struct DayStripSelector: View {
    @Binding var selectedDate: Date

    private var calendar: Calendar { .current }

    /// 供调用方做「选中日期是否还在窗口内」的校验
    static func recentDates(now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Self.recentDates(), id: \.self) { date in
                Button {
                    selectedDate = date
                } label: {
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    VStack(spacing: 1) {
                        Text(dayTitle(for: date))
                            .font(DeliveryBarTheme.Typography.caption)
                            .fontWeight(isSelected ? .medium : .regular)

                        Text(date.formatted(.dateTime.month(.defaultDigits).day()))
                            .font(DeliveryBarTheme.Typography.caption)
                            .foregroundStyle(isSelected ? DeliveryBarTheme.inkSoft : DeliveryBarTheme.softText)
                    }
                    .foregroundStyle(DeliveryBarTheme.pillForeground(isSelected: isSelected))
                    .selectablePill(isSelected: isSelected, verticalPadding: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayTitle(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.weekday(.narrow))
    }
}
