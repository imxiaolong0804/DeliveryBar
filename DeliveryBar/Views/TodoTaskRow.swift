//
//  TodoTaskRow.swift
//  DeliveryBar
//

import SwiftUI

struct TodoTaskRow: View {
    let task: TemporaryTask
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        CompactTaskRow(copyText: task.copyText, onDelete: onDelete) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(task.isCompleted ? DeliveryBarTheme.accent : DeliveryBarTheme.muted)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .help(task.isCompleted ? "标记为未完成" : "完成")
        } content: {
            Text(task.title)
                .font(DeliveryBarTheme.Typography.caption)
                .fontWeight(task.isCompleted ? .regular : .medium)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? DeliveryBarTheme.softText : DeliveryBarTheme.ink)
                .lineLimit(1)

            if !task.note.isEmpty {
                Text(task.note)
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .lineLimit(2)
            }
        }
    }
}
