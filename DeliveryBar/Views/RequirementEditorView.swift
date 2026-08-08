//
//  RequirementEditorView.swift
//  DeliveryBar
//

import SwiftData
import SwiftUI

struct RequirementEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonProfile.lastUsedAt, order: .reverse) private var personProfiles: [PersonProfile]
    @FocusState private var focusedField: EditorField?

    private let requirement: Requirement?
    private let onCancel: () -> Void
    private let onComplete: () -> Void

    @State private var title: String
    @State private var owner: String
    @State private var tester: String
    @State private var detail: String
    @State private var note: String
    @State private var link: String
    @State private var status: RequirementStatus
    @State private var priority: RequirementPriority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var validationMessage: String?
    @State private var isConfirmingDelete = false

    init(
        requirement: Requirement?,
        onCancel: @escaping () -> Void = {},
        onComplete: @escaping () -> Void = {}
    ) {
        self.requirement = requirement
        self.onCancel = onCancel
        self.onComplete = onComplete
        _title = State(initialValue: requirement?.title ?? "")
        _owner = State(initialValue: requirement?.owner ?? "")
        _tester = State(initialValue: requirement?.tester ?? "")
        _detail = State(initialValue: requirement?.detail ?? "")
        _note = State(initialValue: requirement?.note ?? "")
        _link = State(initialValue: requirement?.link ?? "")
        _status = State(initialValue: requirement?.status ?? .todo)
        _priority = State(initialValue: requirement?.priority ?? .medium)
        _hasDueDate = State(initialValue: requirement?.dueDate != nil)
        _dueDate = State(initialValue: requirement?.dueDate ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    EditorSection("基础信息") {
                        EditorTextField(
                            title: "需求名称",
                            placeholder: "输入需求名称",
                            text: $title,
                            focusedField: $focusedField,
                            field: .title
                        )

                        SuggestionTextField(
                            title: "PM",
                            placeholder: "可选",
                            text: $owner,
                            suggestions: personNames(for: .pm),
                            focusedField: $focusedField,
                            field: .owner
                        )

                        SuggestionTextField(
                            title: "测试人员",
                            placeholder: "可选",
                            text: $tester,
                            suggestions: personNames(for: .qa),
                            focusedField: $focusedField,
                            field: .tester
                        )

                        StatusSelector(selection: $status)
                        PrioritySelector(selection: $priority)

                        EditorTextField(
                            title: "需求链接",
                            placeholder: "如望岳、Jira 链接，可选",
                            text: $link,
                            focusedField: $focusedField,
                            field: .link
                        )
                    }

                    EditorSection("时间") {
                        DueDateSelector(hasDueDate: $hasDueDate, dueDate: $dueDate)
                    }

                    EditorSection("描述") {
                        EditorTextField(
                            title: "需求描述",
                            placeholder: "补充背景、范围或测试要点",
                            text: $detail,
                            focusedField: $focusedField,
                            field: .detail,
                            axis: .vertical,
                            lineLimit: 3...5
                        )

                        EditorTextField(
                            title: "备注",
                            placeholder: "可选",
                            text: $note,
                            focusedField: $focusedField,
                            field: .note,
                            axis: .vertical,
                            lineLimit: 2...4
                        )
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(DeliveryBarTheme.Typography.caption)
                            .foregroundStyle(DeliveryBarTheme.danger)
                            .padding(.horizontal, 4)
                    }

                    if requirement != nil {
                        EditorSection("危险操作") {
                            if isConfirmingDelete {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("确认删除这个需求？")
                                        .font(DeliveryBarTheme.Typography.caption)
                                        .foregroundStyle(DeliveryBarTheme.danger)

                                    HStack {
                                        Button("删除", role: .destructive) {
                                            delete()
                                        }

                                        Button("取消") {
                                            isConfirmingDelete = false
                                        }
                                    }
                                }
                            } else {
                                Button("删除需求", role: .destructive) {
                                    isConfirmingDelete = true
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }

            Divider()

            footer
        }
        .frame(width: 460, height: 480)
        .background(DeliveryBarTheme.panelBackground)
        .tint(DeliveryBarTheme.accent)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                onCancel()
            } label: {
                Label("返回", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .tint(DeliveryBarTheme.accent)

            Text(requirement == nil ? "新增需求" : "编辑需求")
                .font(DeliveryBarTheme.Typography.windowTitle)
                .foregroundStyle(DeliveryBarTheme.ink)

            Spacer()
        }
        .padding(12)
    }

    private var footer: some View {
        HStack {
            // cancelAction 让 Esc 先被编辑页消费（回列表），而不是直接收掉整个面板
            Button("取消") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("保存") {
                save()
            }
            .buttonStyle(.borderedProminent)
            .tint(DeliveryBarTheme.accent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    private func save() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTester = tester.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedTester: String? = normalizedTester.isEmpty ? nil : normalizedTester
        guard !normalizedTitle.isEmpty else {
            validationMessage = "需求名称不能为空"
            return
        }
        rememberPerson(owner, role: .pm)
        rememberPerson(normalizedTester, role: .qa)

        if let requirement {
            requirement.title = normalizedTitle
            requirement.owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
            requirement.tester = savedTester
            requirement.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            requirement.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            requirement.link = link.trimmingCharacters(in: .whitespacesAndNewlines)
            requirement.priority = priority
            requirement.status = status
            requirement.dueDate = hasDueDate ? dueDate : nil
            requirement.touch()
        } else {
            let newRequirement = Requirement(
                title: normalizedTitle,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                link: link.trimmingCharacters(in: .whitespacesAndNewlines),
                status: status,
                priority: priority,
                owner: owner.trimmingCharacters(in: .whitespacesAndNewlines),
                tester: savedTester,
                dueDate: hasDueDate ? dueDate : nil
            )
            modelContext.insert(newRequirement)
        }

        modelContext.saveChanges()
        onComplete()
    }

    private func personNames(for role: PersonRole) -> [String] {
        personProfiles
            .filter { $0.role == role }
            .sorted { lhs, rhs in
                if lhs.lastUsedAt != rhs.lastUsedAt {
                    return lhs.lastUsedAt > rhs.lastUsedAt
                }
                return lhs.usageCount > rhs.usageCount
            }
            .map(\.name)
    }

    private func rememberPerson(_ value: String, role: PersonRole) {
        let normalizedName = PersonProfile.normalize(value)
        guard !normalizedName.isEmpty else { return }
        let displayName = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingProfile = personProfiles.first(where: {
            $0.role == role && $0.normalizedName == normalizedName
        }) {
            existingProfile.markUsed(name: displayName)
        } else {
            modelContext.insert(PersonProfile(name: displayName, role: role))
        }
    }

    private func delete() {
        if let requirement {
            modelContext.delete(requirement)
            modelContext.saveChanges()
        }
        onComplete()
    }
}

private enum EditorField: Hashable {
    case title
    case owner
    case tester
    case detail
    case note
    case link
}

private struct DueDateSelector: View {
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date

    private let quickOptions: [(title: String, days: Int)] = [
        ("今天", 0),
        ("明天", 1),
        ("7天", 7),
        ("14天", 14),
        ("30天", 30)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("设置预计交付时间", isOn: $hasDueDate)

            if hasDueDate {
                HStack(spacing: 8) {
                    Button {
                        shiftDueDate(by: -1)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)

                    Text(dueDate.formatted(.dateTime.year().month().day()))
                        .font(DeliveryBarTheme.Typography.caption)
                        .frame(maxWidth: .infinity)

                    Button {
                        shiftDueDate(by: 1)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(quickOptions, id: \.days) { option in
                        Button(option.title) {
                            setDueDate(after: option.days)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func shiftDueDate(by days: Int) {
        let calendar = Calendar.current
        dueDate = calendar.date(byAdding: .day, value: days, to: dueDate) ?? dueDate
    }

    private func setDueDate(after days: Int) {
        let calendar = Calendar.current
        dueDate = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: Date())) ?? Date()
    }
}

private struct StatusSelector: View {
    @Binding var selection: RequirementStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("需求状态")
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(RequirementStatus.editableList) { status in
                    let isSelected = selection == status
                    Button {
                        selection = status
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(status.tintColor)
                                .frame(width: 6, height: 6)

                            Text(status.title)
                                .lineLimit(1)
                        }
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(DeliveryBarTheme.pillForeground(isSelected: isSelected))
                        .selectablePill(isSelected: isSelected, verticalPadding: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PrioritySelector: View {
    @Binding var selection: RequirementPriority

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("优先级")
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            HStack(spacing: 8) {
                ForEach([RequirementPriority.high, .medium, .low]) { priority in
                    Button {
                        selection = priority
                    } label: {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Text(priority.rankTitle)
                                    .font(DeliveryBarTheme.Typography.captionStrong)

                                Text(priority.badgeTitle)
                                    .font(DeliveryBarTheme.Typography.captionStrong)
                            }

                            Text(priority.helperText)
                                .font(DeliveryBarTheme.Typography.caption)
                                .foregroundStyle(DeliveryBarTheme.softText)
                        }
                        .selectablePill(isSelected: selection == priority, verticalPadding: 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(priority.tintColor)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
