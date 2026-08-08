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
        .deliveryCard(padding: 10)
        .hoverHighlight(cornerRadius: DeliveryBarTheme.Radius.card)
        .contextMenu { copyMenu }
    }

    @ViewBuilder
    private var copyMenu: some View {
        Button("复制标题") { Clipboard.copy(requirement.title) }

        if !requirement.link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button("复制链接") { Clipboard.copy(requirement.link) }
        }

        if !requirement.detail.isEmpty {
            Button("复制描述") { Clipboard.copy(requirement.detail) }
        }

        Divider()

        Button("复制全部信息") { Clipboard.copy(fullCopyText) }
    }

    private var fullCopyText: String {
        var lines = ["\(requirement.priority.rankTitle) \(requirement.title)"]
        lines.append("状态：\(requirement.status.compactTitle)")
        lines.append("PM：\(displayPM) / 测试：\(displayTester)")
        if let dueDate = requirement.dueDate {
            lines.append("预计交付：\(dueDate.formatted(.dateTime.year().month().day()))")
        }
        if !requirement.detail.isEmpty {
            lines.append("描述：\(requirement.detail)")
        }
        if !requirement.note.isEmpty {
            lines.append("备注：\(requirement.note)")
        }
        if !requirement.link.isEmpty {
            lines.append("链接：\(requirement.link)")
        }
        return lines.joined(separator: "\n")
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
        .font(DeliveryBarTheme.Typography.caption)
        .buttonStyle(.borderless)
        .fixedSize()
    }

    private var detailView: some View {
        Group {
            if !requirement.detail.isEmpty {
                Text(requirement.detail)
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .lineLimit(2)
                    .textSelection(.enabled)
            } else {
                Text("暂无描述")
                    .foregroundStyle(DeliveryBarTheme.softText.opacity(0.64))
                    .lineLimit(1)
            }
        }
        .font(DeliveryBarTheme.Typography.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 人员/更新时间可以被截断，到期与提醒不行——它们才是这一行的重点
    private var metadataRow: some View {
        HStack(spacing: 6) {
            statusPill

            Text(peopleSummary)
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)
                .lineLimit(1)
                .truncationMode(.tail)
                .textSelection(.enabled)

            Spacer(minLength: 0)

            if let dueText {
                Text(dueText)
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .fixedSize()
            }

            if let attentionReason {
                Text(attentionReason)
                    .font(DeliveryBarTheme.Typography.captionStrong)
                    .foregroundStyle(DeliveryBarTheme.danger)
                    .fixedSize()
            }
        }
    }

    private var peopleSummary: String {
        [
            "PM \(displayPM)",
            "测试 \(displayTester)",
            DateUtils.relativeUpdateText(for: requirement.updatedAt)
        ].joined(separator: " · ")
    }

    /// 逾期 / 今天到期已经由右侧红色提醒承载，这里不重复一遍
    private var dueText: String? {
        guard let dueDate = requirement.dueDate else { return nil }
        let text = DateUtils.dueText(for: dueDate)
        return text == attentionReason ? nil : text
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
                    .font(DeliveryBarTheme.Typography.captionStrong)
                    .foregroundStyle(DeliveryBarTheme.softText)

                Text(actionTitle)
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DeliveryBarTheme.softText)

                StatusPill(status: nextStatus)

                Spacer()

                Button(actionTitle) {
                    onChangeStatus(nextStatus)
                }
                .font(DeliveryBarTheme.Typography.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(DeliveryBarTheme.accent)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(DeliveryBarTheme.quietFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .textSelection(.enabled)
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
        .font(DeliveryBarTheme.Typography.captionStrong)
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

/// 状态胶囊：中性底色，仅用小圆点承载状态色
private struct StatusPill: View {
    let status: RequirementStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.tintColor)
                .frame(width: 5, height: 5)

            Text(status.compactTitle)
        }
        .font(DeliveryBarTheme.Typography.caption)
        .foregroundStyle(DeliveryBarTheme.softText)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(DeliveryBarTheme.quietFill, in: Capsule())
        .overlay {
            Capsule()
                .stroke(DeliveryBarTheme.cardStroke)
        }
    }
}

private struct PriorityPill: View {
    let priority: RequirementPriority

    var body: some View {
        Text(priority.rankTitle)
            .font(DeliveryBarTheme.Typography.captionStrong)
            .foregroundStyle(priority.tintColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(DeliveryBarTheme.quietFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(DeliveryBarTheme.cardStroke)
            }
            .help("\(priority.rankTitle) \(priority.helperText)")
    }
}

private struct StatusChoiceStrip: View {
    let currentStatus: RequirementStatus
    let onSelect: (RequirementStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("切换状态")
                .font(DeliveryBarTheme.Typography.captionStrong)
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
                        .font(DeliveryBarTheme.Typography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(currentStatus == status ? DeliveryBarTheme.accent : DeliveryBarTheme.muted)

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

    /// 极简配色：红色只留给 P0，其余优先级用灰阶区分
    var tintColor: Color {
        switch self {
        case .low:
            DeliveryBarTheme.muted
        case .medium:
            Color(nsColor: .secondaryLabelColor)
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
}
