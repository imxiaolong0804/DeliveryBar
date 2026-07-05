//
//  RequirementRowView.swift
//  DeliveryBar
//

import SwiftUI
import AppKit

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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(requirement.priority.tintColor)
                    .frame(width: requirement.priority.sideBarWidth)
                    .frame(maxHeight: .infinity)
                    .help("\(requirement.priority.rankTitle) \(requirement.priority.helperText)")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        titleView
                            .layoutPriority(1)

                        actionButtons
                    }

                    detailView

                    metadataRow

                    nextStepRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .deliveryCard(padding: 10, stroke: rowStroke, background: rowBackground)
        .hoverHighlight(cornerRadius: DeliveryBarTheme.Radius.card)
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 6) {
            Button("编辑", action: onEdit)

            if onDelete != nil {
                Button("删除", role: .destructive) {
                    withAnimation(.snappy(duration: 0.16)) {
                        isConfirmingDelete.toggle()
                        isSelectingStatus = false
                    }
                }
            }

            if let onRestore {
                Button("恢复", action: onRestore)
            }
        }
        .font(.caption2)
        .buttonStyle(.borderless)
        .fixedSize()
    }

    private var detailView: some View {
        Group {
            if !requirement.detail.isEmpty {
                Text(requirement.detail)
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .lineLimit(2)
            } else {
                Text("暂无描述")
                    .foregroundStyle(DeliveryBarTheme.softText.opacity(0.64))
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataRow: some View {
        HStack(spacing: 6) {
            statusPill
            InfoPill(text: "PM \(displayPM)")
            InfoPill(text: "测试 \(displayTester)")
            InfoPill(text: DateUtils.relativeUpdateText(for: requirement.updatedAt))

            if let dueDate = requirement.dueDate {
                InfoPill(text: DateUtils.dueText(for: dueDate))
            }

            if let attentionReason {
                InfoPill(text: attentionReason, tint: DeliveryBarTheme.danger, isEmphasized: true)
                    .layoutPriority(1)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var nextStepRow: some View {
        if
            let nextStatus = requirement.status.nextStatus,
            let actionTitle = requirement.status.nextActionTitle,
            let onChangeStatus
        {
            HStack(spacing: 6) {
                Text("下一步")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(DeliveryBarTheme.softText)

                Text(actionTitle)
                    .font(.caption2)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DeliveryBarTheme.softText)

                StatusPill(status: nextStatus)

                Spacer()

                Button(actionTitle) {
                    onChangeStatus(nextStatus)
                }
                .font(.caption2)
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(nextStatus.tintColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .quinarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(nextStatus.tintColor.opacity(0.16))
            }
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        if onChangeStatus != nil {
            Button {
                withAnimation(.snappy(duration: 0.16)) {
                    isSelectingStatus.toggle()
                    isConfirmingDelete = false
                }
            } label: {
                StatusPill(status: requirement.status)
            }
            .buttonStyle(.plain)
        } else {
            StatusPill(status: requirement.status)
        }
    }

    private var rowStroke: Color {
        if attentionReason != nil {
            return DeliveryBarTheme.danger.opacity(0.36)
        }
        return requirement.priority.tintColor.opacity(0.28)
    }

    private var rowBackground: Color {
        if attentionReason != nil {
            return DeliveryBarTheme.danger.opacity(0.08)
        }

        switch requirement.priority {
        case .high:
            return DeliveryBarTheme.danger.opacity(0.07)
        case .medium:
            return DeliveryBarTheme.accent.opacity(0.08)
        case .low:
            return DeliveryBarTheme.cardBackground
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if let requirementURL {
            Button {
                NSWorkspace.shared.open(requirementURL)
            } label: {
                titleLabel(isLinked: true)
            }
            .buttonStyle(.plain)
            .help(requirement.link)
        } else {
            titleLabel(isLinked: false)
        }
    }

    private func titleLabel(isLinked: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            PriorityPill(priority: requirement.priority)
                .layoutPriority(1)

            Text(requirement.title)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if isLinked {
                Image(systemName: "link")
                    .font(.system(size: 9, weight: .semibold))
                    .imageScale(.small)
            }
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(isLinked ? DeliveryBarTheme.accent : DeliveryBarTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var requirementURL: URL? {
        let normalizedLink = requirement.link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLink.isEmpty else { return nil }
        return URL(string: normalizedLink)
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

private struct StatusPill: View {
    let status: RequirementStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.tintColor)
                .frame(width: 5, height: 5)

            Text(status.compactTitle)
        }
        .font(.caption2)
        .foregroundStyle(status.tintColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(status.tintColor.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(status.tintColor.opacity(0.22))
        }
    }
}

private struct PriorityPill: View {
    let priority: RequirementPriority

    var body: some View {
        HStack(spacing: 4) {
            Text(priority.rankTitle)
                .fontWeight(.bold)

            Text(priority.badgeTitle)
        }
        .font(.caption2)
        .foregroundStyle(priority.tintColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(priority.tintColor.opacity(priority.backgroundOpacity), in: Capsule())
        .overlay {
            Capsule()
                .stroke(priority.tintColor.opacity(priority.strokeOpacity))
        }
        .help("\(priority.rankTitle) \(priority.helperText)")
    }
}

private struct InfoPill: View {
    let text: String
    var tint: Color = DeliveryBarTheme.softText
    var isEmphasized = false

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(isEmphasized ? .semibold : .regular)
            .foregroundStyle(tint)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(backgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(isEmphasized ? 0.20 : 0.08))
            }
    }

    private var backgroundColor: Color {
        isEmphasized ? tint.opacity(0.10) : Color(nsColor: .quinarySystemFill)
    }
}

private struct StatusChoiceStrip: View {
    let currentStatus: RequirementStatus
    let onSelect: (RequirementStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("切换状态")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(DeliveryBarTheme.softText)

            HStack(spacing: 4) {
                ForEach(Array(RequirementStatus.editableList.enumerated()), id: \.element.id) { index, status in
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
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(currentStatus == status ? status.tintColor : DeliveryBarTheme.muted)

                    if index < RequirementStatus.editableList.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(DeliveryBarTheme.softText.opacity(0.72))
                    }
                }
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
            "测试中"
        case .waitingRelease:
            "待上线"
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
            Color(nsColor: .systemOrange)
        case .waitingAcceptance:
            Color(nsColor: .systemOrange)
        case .waitingRelease:
            Color(nsColor: .systemPurple)
        case .completed:
            DeliveryBarTheme.success
        case .archived:
            DeliveryBarTheme.muted
        }
    }
}

extension RequirementPriority {
    var badgeTitle: String {
        switch self {
        case .low:
            "低"
        case .medium:
            "中"
        case .high:
            "高"
        }
    }

    var rankTitle: String {
        switch self {
        case .low:
            "P2"
        case .medium:
            "P1"
        case .high:
            "P0"
        }
    }

    var helperText: String {
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

    var sideBarWidth: CGFloat {
        switch self {
        case .low:
            4
        case .medium:
            5
        case .high:
            7
        }
    }

    var backgroundOpacity: Double {
        switch self {
        case .low:
            0.10
        case .medium:
            0.14
        case .high:
            0.16
        }
    }

    var strokeOpacity: Double {
        switch self {
        case .low:
            0.18
        case .medium:
            0.26
        case .high:
            0.32
        }
    }
}
