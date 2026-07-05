//
//  QuickEntryEditorView.swift
//  DeliveryBar
//

import SwiftData
import SwiftUI

struct QuickEntryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: QuickEditorField?

    private let entry: QuickEntry?
    private let existingKeys: [String]
    private let existingTags: [String]
    private let onCancel: () -> Void
    private let onComplete: () -> Void

    @State private var key: String
    @State private var value: String
    @State private var type: QuickEntryType
    @State private var note: String
    @State private var tag: String
    @State private var validationMessage: String?
    @State private var isConfirmingDelete = false
    @State private var isShowingTagSuggestions = false

    init(
        entry: QuickEntry?,
        existingKeys: [String] = [],
        existingTags: [String] = [],
        onCancel: @escaping () -> Void = {},
        onComplete: @escaping () -> Void = {}
    ) {
        self.entry = entry
        self.existingKeys = existingKeys
        self.existingTags = existingTags
        self.onCancel = onCancel
        self.onComplete = onComplete
        _key = State(initialValue: entry?.key ?? "")
        _value = State(initialValue: entry?.value ?? "")
        _type = State(initialValue: entry?.type ?? .link)
        _note = State(initialValue: entry?.note ?? "")
        _tag = State(initialValue: entry?.tag ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    QuickEditorSection("基础信息") {
                        QuickEditorTextField(
                            title: "Key",
                            placeholder: "简短别名，如 deploy-prod",
                            text: $key,
                            focusedField: $focusedField,
                            field: .key
                        )

                        TypeSelector(selection: $type)

                        QuickEditorTextField(
                            title: type == .link ? "URL" : "内容",
                            placeholder: type == .link ? "https://..." : "脚本或文本内容",
                            text: $value,
                            focusedField: $focusedField,
                            field: .value,
                            axis: .vertical,
                            lineLimit: 2...6
                        )
                    }

                    QuickEditorSection("备注与分类") {
                        QuickEditorTextField(
                            title: "备注",
                            placeholder: "可选",
                            text: $note,
                            focusedField: $focusedField,
                            field: .note,
                            axis: .vertical,
                            lineLimit: 2...4
                        )

                        TagField(
                            text: $tag,
                            suggestions: existingTags,
                            isShowingSuggestions: $isShowingTagSuggestions
                        )
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(DeliveryBarTheme.danger)
                            .padding(.horizontal, 4)
                    }

                    if entry != nil {
                        QuickEditorSection("危险操作") {
                            if isConfirmingDelete {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("确认删除这个快捷录？")
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
                                Button("删除快捷录", role: .destructive) {
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
        .frame(width: 460, height: 420)
        .background(DeliveryBarTheme.panelBackground)
        .tint(DeliveryBarTheme.accent)
        .onAppear {
            focusedField = .key
        }
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

            Text(entry == nil ? "新增快捷录" : "编辑快捷录")
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
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedKey.isEmpty else {
            validationMessage = "Key 不能为空"
            return
        }

        guard !normalizedValue.isEmpty else {
            validationMessage = type == .link ? "URL 不能为空" : "内容不能为空"
            return
        }

        if type == .link, URL(string: normalizedValue) == nil {
            validationMessage = "链接格式不正确，请输入有效的 URL"
            return
        }

        let conflictingKeys = existingKeys.map { $0.lowercased() }
        if conflictingKeys.contains(normalizedKey.lowercased()) {
            validationMessage = "Key 已存在，请换一个"
            return
        }

        let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)

        if let entry {
            entry.key = normalizedKey
            entry.value = normalizedValue
            entry.type = type
            entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.tag = normalizedTag
            entry.touch()
        } else {
            let newEntry = QuickEntry(
                key: normalizedKey,
                value: normalizedValue,
                type: type,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                tag: normalizedTag
            )
            modelContext.insert(newEntry)
        }

        saveContext()
        onComplete()
    }

    private func delete() {
        if let entry {
            modelContext.delete(entry)
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

// MARK: - Editor Field Enum

private enum QuickEditorField: Hashable {
    case key
    case value
    case note
    case tag
}

// MARK: - Editor Section

private struct QuickEditorSection<Content: View>: View {
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
            .deliveryCard(padding: 10)
        }
    }
}

// MARK: - Editor Field

private struct QuickEditorTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let focusedField: FocusState<QuickEditorField?>.Binding
    let field: QuickEditorField
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

// MARK: - Type Selector

private struct TypeSelector: View {
    @Binding var selection: QuickEntryType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("类型")
                .font(.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            HStack(spacing: 8) {
                ForEach(QuickEntryType.allCases) { type in
                    Button {
                        selection = type
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: type.systemImage)
                                .font(.system(size: 11))
                            Text(type.title)
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .selectablePill(isSelected: selection == type, tint: type.tintColor, verticalPadding: 6)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(type.tintColor)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tag Field

private struct TagField: View {
    @Binding var text: String
    let suggestions: [String]
    @Binding var isShowingSuggestions: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("标签")
                .font(.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    TextField("可选分类标签", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)

                    if !suggestions.isEmpty {
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
                }

                if isShowingSuggestions {
                    tagChips
                }
            }
        }
    }

    @ViewBuilder
    private var tagChips: some View {
        if suggestions.isEmpty {
            Text("暂无标签")
                .font(.caption2)
                .foregroundStyle(DeliveryBarTheme.softText)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        text = suggestion
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
