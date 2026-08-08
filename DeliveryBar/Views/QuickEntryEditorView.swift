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
                    EditorSection("基础信息") {
                        EditorTextField(
                            title: "Key",
                            placeholder: "简短别名，如 deploy-prod",
                            text: $key,
                            focusedField: $focusedField,
                            field: .key
                        )

                        TypeSelector(selection: $type)

                        EditorTextField(
                            title: type == .link ? "URL" : "内容",
                            placeholder: type == .link ? "https://..." : "脚本或文本内容",
                            text: $value,
                            focusedField: $focusedField,
                            field: .value,
                            axis: .vertical,
                            lineLimit: 2...6
                        )
                    }

                    EditorSection("备注与分类") {
                        EditorTextField(
                            title: "备注",
                            placeholder: "可选",
                            text: $note,
                            focusedField: $focusedField,
                            field: .note,
                            axis: .vertical,
                            lineLimit: 2...4
                        )

                        SuggestionTextField(
                            title: "标签",
                            placeholder: "可选分类标签",
                            text: $tag,
                            suggestions: existingTags,
                            focusedField: $focusedField,
                            field: .tag
                        )
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(DeliveryBarTheme.Typography.caption)
                            .foregroundStyle(DeliveryBarTheme.danger)
                            .padding(.horizontal, 4)
                    }

                    if entry != nil {
                        EditorSection("危险操作") {
                            if isConfirmingDelete {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("确认删除这个快捷录？")
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

        modelContext.saveChanges()
        onComplete()
    }

    private func delete() {
        if let entry {
            modelContext.delete(entry)
            modelContext.saveChanges()
        }
        onComplete()
    }
}

// MARK: - Editor Field Enum

private enum QuickEditorField: Hashable {
    case key
    case value
    case note
    case tag
}

// MARK: - Type Selector

private struct TypeSelector: View {
    @Binding var selection: QuickEntryType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("类型")
                .font(DeliveryBarTheme.Typography.caption)
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
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(DeliveryBarTheme.pillForeground(isSelected: selection == type))
                        .selectablePill(isSelected: selection == type, verticalPadding: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
