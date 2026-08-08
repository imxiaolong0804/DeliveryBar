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
    /// 和格式化模式共用一份字号设置，A- / A+ 调一次两个模式都跟着变
    @AppStorage("jsonEditorFontSize") private var editorFontSize = Double(JSONSyntaxTheme.defaultFontSize)

    var body: some View {
        GeometryReader { proxy in
            splitContent(availableHeight: proxy.size.height)
        }
        .padding(DeliveryBarTheme.Spacing.lg)
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
                paneLength: paneHeight,
                minRatio: Layout.minResultPaneRatio,
                maxRatio: Layout.maxResultPaneRatio,
                handleLength: Layout.splitHandleWidth
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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(DeliveryBarTheme.Typography.captionStrong)
                    .foregroundStyle(DeliveryBarTheme.softText)

                Spacer()

                Text("\(text.wrappedValue.count) 字符")
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.muted)
                    .monospacedDigit()
            }
            .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
            .padding(.vertical, DeliveryBarTheme.Spacing.md)

            SearchableJSONTextView(
                text: text,
                isEditable: true,
                searchRequest: nil,
                searchResult: .constant(nil),
                editingState: nil,
                fontSize: CGFloat(editorFontSize)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // 比对时两边是平等的，底色用同一档，不像格式化那样分主次
        .background(Color.dynamic(light: .white.withAlphaComponent(0.4), dark: .black.withAlphaComponent(0.22)))
        .clipShape(RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous))
    }

    private var resultsPane: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("差异")
                    .font(DeliveryBarTheme.Typography.captionStrong)
                    .foregroundStyle(DeliveryBarTheme.softText)

                Spacer()

                if hasCompared, leftError == nil, rightError == nil, !entries.isEmpty {
                    Text("共 \(entries.count) 处 · 新增 \(count(of: .added)) · 缺失 \(count(of: .removed)) · 不同 \(count(of: .changed))")
                        .font(DeliveryBarTheme.Typography.caption)
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
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let rightError {
                Label("右侧：\(rightError)", systemImage: "exclamationmark.triangle.fill")
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(DeliveryBarTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var identicalContent: some View {
        Label("两边一致", systemImage: "checkmark.circle.fill")
            .font(DeliveryBarTheme.Typography.caption)
            .foregroundStyle(DeliveryBarTheme.success)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(DeliveryBarTheme.Typography.caption)
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
            .padding(DeliveryBarTheme.Spacing.xs)
        }
    }

    private func diffRow(_ entry: JSONDiffEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.kind.title)
                    .font(DeliveryBarTheme.Typography.captionStrong)
                    .foregroundStyle(entry.kind.tintColor)
                    .padding(.horizontal, DeliveryBarTheme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(entry.kind.tintColor.opacity(0.16), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(entry.kind.tintColor.opacity(0.30))
                    }

                Text(entry.path)
                    .font(DeliveryBarTheme.Typography.monoStrong)
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
        .contextMenu {
            Button("复制路径") { Clipboard.copy(entry.path) }
            Button("复制该差异") { Clipboard.copy(diffCopyText(entry)) }
        }
    }

    private func diffCopyText(_ entry: JSONDiffEntry) -> String {
        switch entry.kind {
        case .added:
            "\(entry.kind.title) \(entry.path)：\(entry.rightText ?? "")"
        case .removed:
            "\(entry.kind.title) \(entry.path)：\(entry.leftText ?? "")"
        case .changed:
            "\(entry.kind.title) \(entry.path)：\(entry.leftText ?? "") → \(entry.rightText ?? "")"
        }
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
            .font(DeliveryBarTheme.Typography.mono)
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
