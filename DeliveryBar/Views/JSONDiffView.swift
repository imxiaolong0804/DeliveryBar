//
//  JSONDiffView.swift
//  DeliveryBar
//
//  JSON 比对模式内容区：左右输入 + 结构化差异列表。
//

import AppKit
import SwiftUI

struct JSONDiffView: View {
    private enum Layout {
        static let editorMinHeight: CGFloat = 96
        static let splitHandleHeight: CGFloat = 16
        static let splitHandleWidth: CGFloat = 52
        static let minResultPaneRatio = 0.18
        static let maxResultPaneRatio = 0.82
    }

    @Binding var leftText: String
    @Binding var rightText: String
    let entries: [JSONDiffEntry]
    let leftError: String?
    let rightError: String?
    let hasCompared: Bool

    @AppStorage("jsonDiffResultPaneRatio") private var resultPaneRatio = 0.45

    var body: some View {
        GeometryReader { proxy in
            splitContent(availableHeight: proxy.size.height)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func splitContent(availableHeight: CGFloat) -> some View {
        let paneHeight = max(1, availableHeight - Layout.splitHandleHeight)
        let minPaneHeight = min(Layout.editorMinHeight, paneHeight / 2)
        let rawResultHeight = paneHeight * CGFloat(clampedRatio(resultPaneRatio))
        let resultHeight = min(max(rawResultHeight, minPaneHeight), paneHeight - minPaneHeight)
        let editorsHeight = paneHeight - resultHeight

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                editorSection(title: "左侧 JSON", text: $leftText)
                editorSection(title: "右侧 JSON", text: $rightText)
            }
            .frame(height: editorsHeight)

            JSONPaneSplitHandle(
                resultPaneRatio: $resultPaneRatio,
                paneHeight: paneHeight,
                minRatio: Layout.minResultPaneRatio,
                maxRatio: Layout.maxResultPaneRatio,
                handleWidth: Layout.splitHandleWidth
            )
            .frame(maxWidth: .infinity)
            .frame(height: Layout.splitHandleHeight)
            .help("拖动调整输入和结果区域大小")
            .accessibilityLabel("调整输入和结果区域大小")

            resultsPane
                .frame(height: resultHeight)
        }
    }

    private func editorSection(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Spacer()

                Text("\(text.wrappedValue.count) 字符")
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
            }

            SearchableJSONTextView(
                text: text,
                isEditable: true,
                searchRequest: nil,
                searchResult: .constant(nil),
                editingState: nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .deliveryCard(padding: 6, background: DeliveryBarTheme.cardBackground)
        }
    }

    private var resultsPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("差异")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Spacer()

                if hasCompared, leftError == nil, rightError == nil, !entries.isEmpty {
                    Text("共 \(entries.count) 处差异 · 新增 \(count(of: .added)) · 缺失 \(count(of: .removed)) · 不同 \(count(of: .changed))")
                        .font(.caption)
                        .foregroundStyle(DeliveryBarTheme.softText)
                }
            }

            Group {
                if leftError != nil || rightError != nil {
                    errorContent
                } else if !hasCompared {
                    placeholder("输入两侧 JSON 后点击「比对」")
                } else if entries.isEmpty {
                    identicalContent
                } else {
                    diffList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .deliveryCard(padding: 6, background: DeliveryBarTheme.cardBackground)
        }
    }

    private var errorContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let leftError {
                Label("左侧：\(leftError)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let rightError {
                Label("右侧：\(rightError)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var identicalContent: some View {
        Label("两边一致", systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(DeliveryBarTheme.success)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(DeliveryBarTheme.softText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var diffList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(entries) { entry in
                    diffRow(entry)
                }
            }
            .padding(4)
        }
    }

    private func diffRow(_ entry: JSONDiffEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.kind.title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(entry.kind.tintColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.kind.tintColor.opacity(0.16), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(entry.kind.tintColor.opacity(0.30))
                    }

                Text(entry.path)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(DeliveryBarTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Spacer()
            }

            valueLine(entry)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .deliveryCard(padding: 8)
    }

    @ViewBuilder
    private func valueLine(_ entry: JSONDiffEntry) -> some View {
        switch entry.kind {
        case .added:
            valueText("右侧值 \(entry.rightText ?? "")", color: DeliveryBarTheme.success)
        case .removed:
            valueText("左侧值 \(entry.leftText ?? "")", color: DeliveryBarTheme.danger)
        case .changed:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                valueText(entry.leftText ?? "", color: DeliveryBarTheme.danger)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DeliveryBarTheme.softText)

                valueText(entry.rightText ?? "", color: DeliveryBarTheme.success)
            }
        }
    }

    private func valueText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(2)
            .truncationMode(.tail)
            .textSelection(.enabled)
    }

    private func count(of kind: JSONDiffKind) -> Int {
        entries.filter { $0.kind == kind }.count
    }

    private func clampedRatio(_ ratio: Double) -> Double {
        min(max(ratio, Layout.minResultPaneRatio), Layout.maxResultPaneRatio)
    }
}

private extension JSONDiffKind {
    var tintColor: Color {
        switch self {
        case .added:
            DeliveryBarTheme.success
        case .removed:
            DeliveryBarTheme.danger
        case .changed:
            Color(nsColor: .systemOrange)
        }
    }
}
