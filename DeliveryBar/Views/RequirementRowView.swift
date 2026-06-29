//
//  RequirementRowView.swift
//  DeliveryBar
//

import SwiftUI

struct RequirementRowView: View {
    let requirement: Requirement
    let remindersEnabled: Bool
    let onEdit: () -> Void
    let onChangeStatus: ((RequirementStatus) -> Void)?
    let onDelete: (() -> Void)?
    let onRestore: (() -> Void)?

    @State private var isSelectingStatus = false
    @State private var isConfirmingDelete = false

    private var attentionReason: String? {
        ReminderService.attentionReason(for: requirement, remindersEnabled: remindersEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(requirement.status.tintColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(requirement.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(DeliveryBarTheme.ink)
                        .lineLimit(1)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("PM \(displayPM)")
                        Text("测试 \(displayTester)")
                    }
                    .font(.caption2)
                    .foregroundStyle(DeliveryBarTheme.softText)
                }
                .frame(width: 108, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    if !requirement.detail.isEmpty {
                        Text(requirement.detail)
                            .font(.caption)
                            .foregroundStyle(DeliveryBarTheme.softText)
                            .lineLimit(2)
                    } else {
                        Text("暂无描述")
                            .font(.caption)
                            .foregroundStyle(DeliveryBarTheme.softText.opacity(0.64))
                            .lineLimit(1)
                    }

                    HStack(alignment: .center, spacing: 8) {
                        PriorityBadge(priority: requirement.priority)

                        HStack(spacing: 6) {
                            Text(DateUtils.relativeUpdateText(for: requirement.updatedAt))

                            if let dueDate = requirement.dueDate {
                                Text(DateUtils.dueText(for: dueDate))
                            }

                            if let attentionReason {
                                Text(attentionReason)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DeliveryBarTheme.danger)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(DeliveryBarTheme.softText)
                        .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Button("编辑", action: onEdit)
                        .font(.caption2)

                    if onChangeStatus != nil {
                        Button(requirement.status.compactTitle) {
                            withAnimation(.snappy(duration: 0.16)) {
                                isSelectingStatus.toggle()
                                isConfirmingDelete = false
                            }
                        }
                        .font(.caption2)
                    }

                    if onDelete != nil {
                        Button("删除", role: .destructive) {
                            withAnimation(.snappy(duration: 0.16)) {
                                isConfirmingDelete.toggle()
                                isSelectingStatus = false
                            }
                        }
                        .font(.caption2)
                    }

                    if let onRestore {
                        Button("恢复", action: onRestore)
                            .font(.caption2)
                    }
                }
                .buttonStyle(.borderless)
                .frame(width: 58, alignment: .trailing)
            }

            if isConfirmingDelete, let onDelete {
                DeleteConfirmationStrip {
                    onDelete()
                    withAnimation(.snappy(duration: 0.16)) {
                        isConfirmingDelete = false
                    }
                } onCancel: {
                    withAnimation(.snappy(duration: 0.16)) {
                        isConfirmingDelete = false
                    }
                }
            }

            if isSelectingStatus, let onChangeStatus {
                StatusChoiceStrip(currentStatus: requirement.status) { status in
                    onChangeStatus(status)
                    withAnimation(.snappy(duration: 0.16)) {
                        isSelectingStatus = false
                    }
                }
            }
        }
        .padding(8)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(requirement.status.tintColor.opacity(0.26))
        }
    }

    private var displayPM: String {
        requirement.owner.isEmpty ? "待定" : requirement.owner
    }

    private var displayTester: String {
        guard let tester = requirement.tester, !tester.isEmpty else {
            return "待定"
        }
        return tester
    }

    private var rowBackground: Color {
        if attentionReason != nil {
            return DeliveryBarTheme.danger.opacity(0.08)
        }
        return DeliveryBarTheme.cardBackground
    }
}

private struct DeleteConfirmationStrip: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DeliveryBarTheme.danger)

            Text("确认删除？")
                .font(.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            Spacer()

            Button("取消", action: onCancel)
                .font(.caption2)

            Button("删除", role: .destructive, action: onConfirm)
                .font(.caption2)
        }
        .buttonStyle(.borderless)
        .padding(.leading, 12)
    }
}

private struct PriorityBadge: View {
    let priority: RequirementPriority

    var body: some View {
        Text(priority.badgeTitle)
            .font(.callout)
            .fontWeight(.bold)
            .foregroundStyle(priority.tintColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(priority.tintColor.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(priority.tintColor.opacity(0.22))
            }
    }
}

private struct StatusChoiceStrip: View {
    let currentStatus: RequirementStatus
    let onSelect: (RequirementStatus) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 5)], alignment: .leading, spacing: 5) {
            ForEach(RequirementStatus.editableList) { status in
                Button {
                    onSelect(status)
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(status.tintColor)
                            .frame(width: 5, height: 5)

                        Text(status.compactTitle)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .tint(currentStatus == status ? status.tintColor : DeliveryBarTheme.muted)
            }
        }
        .padding(.leading, 12)
    }
}

extension RequirementStatus {
    var compactTitle: String {
        switch self {
        case .todo:
            "待开发"
        case .developing:
            "开发中"
        case .developedNotDelivered:
            "未交付"
        case .waitingAcceptance:
            "待验收"
        case .completed:
            "完成"
        case .archived:
            "归档"
        }
    }

    var tintColor: Color {
        switch self {
        case .todo:
            DeliveryBarTheme.muted
        case .developing:
            DeliveryBarTheme.accent
        case .developedNotDelivered:
            Color(red: 0.78, green: 0.55, blue: 0.18)
        case .waitingAcceptance:
            Color(red: 0.70, green: 0.50, blue: 0.18)
        case .completed:
            DeliveryBarTheme.success
        case .archived:
            DeliveryBarTheme.muted
        }
    }
}

private extension RequirementPriority {
    var badgeTitle: String {
        switch self {
        case .low:
            "低优先级"
        case .medium:
            "中优先级"
        case .high:
            "高优先级"
        }
    }

    var tintColor: Color {
        switch self {
        case .low:
            DeliveryBarTheme.muted
        case .medium:
            DeliveryBarTheme.accent
        case .high:
            DeliveryBarTheme.danger
        }
    }
}
