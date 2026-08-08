//
//  QuickEntryListView.swift
//  DeliveryBar
//

import AppKit
import SwiftData
import SwiftUI

struct QuickEntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [QuickEntry]

    let listHeight: CGFloat
    let onEdit: (QuickEntry) -> Void

    @State private var searchText = ""
    @State private var selectedType: QuickEntryType?
    @State private var copiedKey: String?

    private var filteredEntries: [QuickEntry] {
        var result = entries

        if let selectedType {
            result = result.filter { $0.type == selectedType }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.key.lowercased().contains(query)
                    || $0.value.lowercased().contains(query)
                    || $0.tag.lowercased().contains(query)
                    || $0.note.lowercased().contains(query)
            }
        }

        return result.sorted { lhs, rhs in
            if lhs.usageCount != rhs.usageCount {
                return lhs.usageCount > rhs.usageCount
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchBar
                .padding(10)

            Divider()

            typeFilter

            Divider()

            entryList
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(DeliveryBarTheme.softText)

            TextField("搜索 key、内容、标签或备注...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(DeliveryBarTheme.softText)
                }
                .buttonStyle(.borderless)
            }
        }
        .deliveryCard(padding: 8)
    }

    private var typeFilter: some View {
        HStack(spacing: 6) {
            typePill(label: "全部", count: entries.count, isSelected: selectedType == nil) {
                selectedType = nil
            }

            ForEach(QuickEntryType.allCases) { type in
                typePill(
                    label: type.title,
                    count: entries.filter { $0.type == type }.count,
                    isSelected: selectedType == type
                ) {
                    selectedType = type
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func typePill(label: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .lineLimit(1)

                Text("\(count)")
                    .foregroundStyle(isSelected ? DeliveryBarTheme.inkSoft : DeliveryBarTheme.softText)
            }
            .font(DeliveryBarTheme.Typography.caption)
            .foregroundStyle(DeliveryBarTheme.pillForeground(isSelected: isSelected))
            .selectablePill(isSelected: isSelected, verticalPadding: 5)
        }
        .buttonStyle(.plain)
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        entries.isEmpty ? "暂无快捷录" : "没有匹配的结果",
                        systemImage: entries.isEmpty ? "keyboard" : "magnifyingglass",
                        description: Text(entries.isEmpty ? "保存常用的链接、脚本和文本片段。" : "换个关键词试试。")
                    )
                    .padding(.vertical, 28)
                } else {
                    ForEach(filteredEntries) { entry in
                        QuickEntryRow(
                            entry: entry,
                            isCopied: copiedKey == entry.key,
                            onAction: { performAction(for: entry) },
                            onEdit: { onEdit(entry) },
                            onDelete: {
                                modelContext.delete(entry)
                                modelContext.saveChanges()
                            }
                        )
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: listHeight)
        .clipped()
    }

    private func performAction(for entry: QuickEntry) {
        switch entry.type {
        case .link:
            if let url = URL(string: entry.value) {
                NSWorkspace.shared.open(url)
            }
        case .script, .snippet:
            Clipboard.copy(entry.value)
        }
        entry.markUsed()
        copiedKey = entry.key
        modelContext.saveChanges()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedKey == entry.key {
                copiedKey = nil
            }
        }
    }
}

// MARK: - QuickEntryRow

private struct QuickEntryRow: View {
    let entry: QuickEntry
    let isCopied: Bool
    let onAction: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: entry.type.systemImage)
                    .font(.system(size: 13))
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.key)
                            .font(DeliveryBarTheme.Typography.captionStrong)
                            .foregroundStyle(DeliveryBarTheme.ink)
                            .lineLimit(1)

                        if !entry.tag.isEmpty {
                            Text(entry.tag)
                                .font(DeliveryBarTheme.Typography.caption)
                                .foregroundStyle(DeliveryBarTheme.softText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DeliveryBarTheme.quietFill, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(DeliveryBarTheme.cardStroke)
                                }
                        }
                    }

                    Text(entry.value)
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(DeliveryBarTheme.softText)
                        .lineLimit(1)

                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(DeliveryBarTheme.Typography.caption)
                            .foregroundStyle(DeliveryBarTheme.softText.opacity(0.78))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

                VStack(alignment: .trailing, spacing: 4) {
                    Button {
                        onAction()
                    } label: {
                        Label(isCopied ? "已复制" : entry.type.actionTitle, systemImage: isCopied ? "checkmark" : entry.type.actionImage)
                            .font(DeliveryBarTheme.Typography.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(isCopied ? DeliveryBarTheme.success : DeliveryBarTheme.accent)

                    HStack(spacing: 4) {
                        Button("编辑", action: onEdit)
                            .font(DeliveryBarTheme.Typography.caption)

                        Button("删除", role: .destructive) {
                            withAnimation(.snappy(duration: 0.16)) {
                                isConfirmingDelete.toggle()
                            }
                        }
                        .font(DeliveryBarTheme.Typography.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .frame(width: 68, alignment: .trailing)
            }

            if isConfirmingDelete {
                DeleteConfirmationStrip(leadingInset: 28) {
                    onDelete()
                } onCancel: {
                    withAnimation(.snappy(duration: 0.16)) {
                        isConfirmingDelete = false
                    }
                }
            }
        }
        .deliveryCard(padding: 8)
        .hoverHighlight(cornerRadius: DeliveryBarTheme.Radius.card)
        .contextMenu {
            Button("复制内容") { Clipboard.copy(entry.value) }
            Button("复制 Key") { Clipboard.copy(entry.key) }

            if entry.type == .link, let url = URL(string: entry.value) {
                Divider()
                Button("打开链接") { NSWorkspace.shared.open(url) }
            }
        }
    }
}

// MARK: - Editor Request

struct QuickEntryEditorRequest: Identifiable {
    let id = UUID()
    let entry: QuickEntry?
    let existingKeys: [String]
}
