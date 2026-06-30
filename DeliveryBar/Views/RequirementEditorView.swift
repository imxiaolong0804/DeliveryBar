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

                        PersonNameField(
                            title: "PM",
                            placeholder: "可选",
                            text: $owner,
                            suggestions: personNames(for: .pm),
                            focusedField: $focusedField,
                            field: .owner
                        )

                        PersonNameField(
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
                            placeholder: "补充背景、范围或验收标准",
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
                            .font(.caption)
                            .foregroundStyle(DeliveryBarTheme.danger)
                            .padding(.horizontal, 4)
                    }

                    if requirement != nil {
                        EditorSection("危险操作") {
                            if isConfirmingDelete {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("确认删除这个需求？")
                                        .font(.subheadline)
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
                .font(.headline)
                .foregroundStyle(DeliveryBarTheme.ink)

            Spacer()
        }
        .padding(12)
    }

    private var footer: some View {
        HStack {
            Button("取消") {
                onCancel()
            }

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

        saveContext()
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
            saveContext()
        }
        onComplete()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save model context: \(error)")
        }
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

private struct EditorSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(10)
            .background(DeliveryBarTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DeliveryBarTheme.cardStroke)
            }
        }
    }
}

private struct EditorTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let focusedField: FocusState<EditorField?>.Binding
    let field: EditorField
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            if let lineLimit {
                TextField(placeholder, text: $text, axis: axis)
                    .focused(focusedField, equals: field)
                    .lineLimit(lineLimit)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField.wrappedValue = field
                    }
            } else {
                TextField(placeholder, text: $text, axis: axis)
                    .focused(focusedField, equals: field)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField.wrappedValue = field
                    }
            }
        }
    }
}

private struct PersonNameField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]
    let focusedField: FocusState<EditorField?>.Binding
    let field: EditorField
    @State private var isShowingSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    TextField(placeholder, text: $text)
                        .focused(focusedField, equals: field)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField.wrappedValue = field
                        }

                    Button {
                        withAnimation(.snappy(duration: 0.16)) {
                            isShowingSuggestions.toggle()
                        }
                    } label: {
                        Image(systemName: isShowingSuggestions ? "chevron.up.circle" : "chevron.down.circle")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 28)
                }

                if isShowingSuggestions {
                    suggestionChips
                }
            }
        }
    }

    @ViewBuilder
    private var suggestionChips: some View {
        if suggestions.isEmpty {
            Text("暂无常用姓名")
                .font(.caption2)
                .foregroundStyle(DeliveryBarTheme.softText)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        text = suggestion
                        focusedField.wrappedValue = field
                        withAnimation(.snappy(duration: 0.16)) {
                            isShowingSuggestions = false
                        }
                    }
                    .font(.caption2)
                    .lineLimit(1)
                    .buttonStyle(.bordered)
                    .tint(DeliveryBarTheme.accent)
                    .controlSize(.small)
                }
            }
        }
    }
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
                        .font(.subheadline)
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
                .font(.caption)
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
                        .font(.caption)
                        .foregroundStyle(isSelected ? status.tintColor : DeliveryBarTheme.softText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(statusBackground(for: status, isSelected: isSelected), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(status.tintColor.opacity(isSelected ? 0.55 : 0.18))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBackground(for status: RequirementStatus, isSelected: Bool) -> Color {
        if isSelected {
            return status.tintColor.opacity(0.16)
        }
        return DeliveryBarTheme.cardBackground
    }
}

private struct PrioritySelector: View {
    @Binding var selection: RequirementPriority

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("优先级")
                .font(.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            HStack(spacing: 8) {
                ForEach([RequirementPriority.high, .medium, .low]) { priority in
                    Button {
                        selection = priority
                    } label: {
                        VStack(spacing: 2) {
                            Text(priority.badgeTitle)
                                .font(.subheadline)
                                .fontWeight(.bold)

                            Text(priority.helperText)
                                .font(.caption2)
                                .foregroundStyle(DeliveryBarTheme.softText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(priorityBackground(for: priority), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(priority.tintColor.opacity(selection == priority ? 0.55 : 0.18))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(priority.tintColor)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func priorityBackground(for priority: RequirementPriority) -> Color {
        if selection == priority {
            return priority.tintColor.opacity(0.16)
        }
        return DeliveryBarTheme.cardBackground
    }
}

private extension RequirementPriority {
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

    var helperText: String {
        switch self {
        case .low:
            "可排期"
        case .medium:
            "正常"
        case .high:
            "优先"
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
