//
//  JSONFormatterView.swift
//  DeliveryBar
//

import AppKit
import Combine
import SwiftData
import SwiftUI

struct JSONFormatterView: View {
    private enum Layout {
        static let width: CGFloat = 820
        static let height: CGFloat = 620
        static let historyWidth: CGFloat = 230
        static let editorMinHeight: CGFloat = 96
        static let splitHandleHeight: CGFloat = 16
        static let splitHandleWidth: CGFloat = 52
        static let minResultPaneRatio = 0.18
        static let maxResultPaneRatio = 0.82
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JSONFormatHistory.updatedAt, order: .reverse) private var histories: [JSONFormatHistory]

    let onPinnedChange: (Bool) -> Void
    let onClose: () -> Void

    @State private var inputText: String
    @State private var outputText = ""
    @State private var errorMessage: String?
    @State private var isPinned = false
    @State private var showsHistory = false
    @State private var copiedOutput = false
    @State private var searchText = ""
    @State private var searchTarget: JSONSearchTarget = .output
    @State private var searchStatus: String?
    @State private var inputSearchRequest: JSONTextSearchRequest?
    @State private var outputSearchRequest: JSONTextSearchRequest?
    @State private var inputSearchResult: JSONTextSearchResult?
    @State private var outputSearchResult: JSONTextSearchResult?
    @StateObject private var inputEditingState = JSONTextEditingState()
    @AppStorage("jsonFormatterResultPaneRatio") private var resultPaneRatio = 0.5

    @State private var mode: JSONToolMode = .format
    @State private var diffLeftText = ""
    @State private var diffRightText = ""
    @State private var diffEntries: [JSONDiffEntry] = []
    @State private var diffLeftError: String?
    @State private var diffRightError: String?
    @State private var hasComparedOnce = false

    init(
        onPinnedChange: @escaping (Bool) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        self.onPinnedChange = onPinnedChange
        self.onClose = onClose
        _inputText = State(initialValue: JSONFormatterDraftStore.loadFreshDraft() ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if mode == .format {
                searchBar

                Divider()

                HStack(spacing: 0) {
                    formatterContent

                    if showsHistory {
                        Divider()
                        historyContent
                            .frame(width: Layout.historyWidth)
                    }
                }

                Divider()

                footer
            } else {
                JSONDiffView(
                    leftText: $diffLeftText,
                    rightText: $diffRightText,
                    entries: diffEntries,
                    leftError: diffLeftError,
                    rightError: diffRightError,
                    hasCompared: hasComparedOnce
                )

                Divider()

                diffFooter
            }
        }
        .frame(width: Layout.width, height: Layout.height)
        .background(DeliveryBarTheme.panelBackground)
        .tint(DeliveryBarTheme.accent)
        .onChange(of: inputText) { _, newValue in
            JSONFormatterDraftStore.save(newValue)
        }
        .onChange(of: isPinned) { _, newValue in
            onPinnedChange(newValue)
        }
        .onAppear {
            onPinnedChange(isPinned)
        }
        .onChange(of: inputSearchResult) { _, result in
            updateSearchStatus(result, target: .input)
        }
        .onChange(of: outputSearchResult) { _, result in
            updateSearchStatus(result, target: .output)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "curlybraces")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DeliveryBarTheme.ink)
                .frame(width: 32, height: 32)
                .background(DeliveryBarTheme.accentWash, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DeliveryBarTheme.ink.opacity(0.14))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.title)
                    .font(.headline)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Text(mode.subtitle)
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
            }

            Spacer()

            Picker("", selection: $mode) {
                ForEach(JSONToolMode.allCases) { mode in
                    Text(mode.pickerTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 132)

            Toggle("置顶", isOn: $isPinned)
                .toggleStyle(.switch)
                .font(.caption)

            if mode == .format {
                Button {
                    showsHistory.toggle()
                } label: {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("关闭")
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(DeliveryBarTheme.softText)

            TextField("搜索 JSON 内容", text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    performSearch()
                }

            Picker("", selection: $searchTarget) {
                ForEach(JSONSearchTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 116)

            Button {
                performSearch()
            } label: {
                Label("查找", systemImage: "arrow.down")
            }
            .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let searchStatus {
                Text(searchStatus)
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .lineLimit(1)
                    .frame(width: 126, alignment: .trailing)
            }
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DeliveryBarTheme.barBackground)
    }

    private var formatterContent: some View {
        GeometryReader { proxy in
            splitEditorContent(availableHeight: proxy.size.height)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func splitEditorContent(availableHeight: CGFloat) -> some View {
        let paneHeight = max(1, availableHeight - Layout.splitHandleHeight)
        let minPaneHeight = min(Layout.editorMinHeight, paneHeight / 2)
        let rawResultHeight = paneHeight * CGFloat(clampedResultPaneRatio(resultPaneRatio))
        let resultHeight = min(max(rawResultHeight, minPaneHeight), paneHeight - minPaneHeight)
        let inputHeight = paneHeight - resultHeight

        return VStack(spacing: 0) {
            inputEditor
                .frame(height: inputHeight)

            splitHandle(paneHeight: paneHeight)

            outputEditor
                .frame(height: resultHeight)
        }
    }

    private var inputEditor: some View {
        editorSection(
            title: "输入",
            value: inputText,
            background: DeliveryBarTheme.cardBackground
        ) {
            SearchableJSONTextView(
                text: $inputText,
                isEditable: true,
                searchRequest: inputSearchRequest,
                searchResult: $inputSearchResult,
                editingState: inputEditingState
            )
        }
    }

    private var outputEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.danger)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            editorSection(
                title: "结果",
                value: outputText,
                background: DeliveryBarTheme.cardBackground
            ) {
                SearchableJSONTextView(
                    text: .constant(outputText),
                    isEditable: false,
                    searchRequest: outputSearchRequest,
                    searchResult: $outputSearchResult,
                    editingState: nil
                )
            }
        }
    }

    private func splitHandle(paneHeight: CGFloat) -> some View {
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
    }

    private func editorSection<Content: View>(
        title: String,
        value: String,
        background: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            editorHeader(title: title, value: value)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .deliveryCard(padding: 6, background: background)
        }
    }

    private func editorHeader(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(DeliveryBarTheme.ink)

            Spacer()

            if title == "输入" {
                undoRedoButtons
            }

            Text("\(value.count) 字符")
                .font(.caption)
                .foregroundStyle(DeliveryBarTheme.softText)
        }
    }

    private var undoRedoButtons: some View {
        HStack(spacing: 4) {
            Button {
                inputEditingState.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .disabled(!inputEditingState.canUndo)
            .keyboardShortcut("z", modifiers: .command)
            .help("撤销 (⌘Z)")
            .accessibilityLabel("撤销")

            Button {
                inputEditingState.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(.borderless)
            .disabled(!inputEditingState.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .help("重做 (⇧⌘Z)")
            .accessibilityLabel("重做")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(DeliveryBarTheme.softText)
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("历史")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Spacer()

                Text("\(histories.count)")
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
            }
            .padding(10)

            Divider()

            if histories.isEmpty {
                ContentUnavailableView(
                    "暂无历史",
                    systemImage: "clock",
                    description: Text("格式化成功后会保存在这里。")
                )
                .padding(.vertical, 28)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(histories) { history in
                            historyRow(history)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(DeliveryBarTheme.barBackground)
    }

    private func historyRow(_ history: JSONFormatHistory) -> some View {
        Button {
            restore(history)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(history.summary)
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.ink)
                    .lineLimit(3)

                Text(DateUtils.relativeUpdateText(for: history.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(DeliveryBarTheme.softText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .deliveryCard(padding: 8)
            .hoverHighlight(cornerRadius: DeliveryBarTheme.Radius.card)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                clear()
            } label: {
                Label("清空", systemImage: "trash")
            }

            Spacer()

            Button {
                compress()
            } label: {
                Label("压缩", systemImage: "arrow.down.forward.and.arrow.up.backward")
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                format()
            } label: {
                Label("格式化", systemImage: "wand.and.sparkles")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                copyOutput()
            } label: {
                Label(copiedOutput ? "已复制" : "复制结果", systemImage: copiedOutput ? "checkmark" : "doc.on.doc")
            }
            .disabled(outputText.isEmpty)
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DeliveryBarTheme.footerBackground)
    }

    private var diffFooter: some View {
        HStack(spacing: 8) {
            Button {
                clearDiff()
            } label: {
                Label("清空", systemImage: "trash")
            }

            Spacer()

            Button {
                swapDiffSides()
            } label: {
                Label("交换左右", systemImage: "arrow.left.arrow.right")
            }
            .disabled(diffLeftText.isEmpty && diffRightText.isEmpty)

            Button {
                runDiff()
            } label: {
                Label("比对", systemImage: "square.split.2x1")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canRunDiff)
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DeliveryBarTheme.footerBackground)
    }

    private var canRunDiff: Bool {
        !diffLeftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !diffRightText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func runDiff() {
        hasComparedOnce = true
        diffEntries = []
        diffLeftError = nil
        diffRightError = nil

        var leftValue: OrderedJSONValue?
        do {
            leftValue = try OrderedJSONParser(text: diffLeftText.trimmingCharacters(in: .whitespacesAndNewlines)).parse()
        } catch {
            diffLeftError = JSONFormatterEngine.message(for: error)
        }

        var rightValue: OrderedJSONValue?
        do {
            rightValue = try OrderedJSONParser(text: diffRightText.trimmingCharacters(in: .whitespacesAndNewlines)).parse()
        } catch {
            diffRightError = JSONFormatterEngine.message(for: error)
        }

        guard let leftValue, let rightValue else { return }
        diffEntries = JSONDiffEngine.diff(left: leftValue, right: rightValue)
    }

    private func swapDiffSides() {
        (diffLeftText, diffRightText) = (diffRightText, diffLeftText)
        if hasComparedOnce {
            runDiff()
        }
    }

    private func clearDiff() {
        diffLeftText = ""
        diffRightText = ""
        diffEntries = []
        diffLeftError = nil
        diffRightError = nil
        hasComparedOnce = false
    }

    private func format() {
        transformJSON(options: [.prettyPrinted, .withoutEscapingSlashes])
    }

    private func compress() {
        transformJSON(options: [.withoutEscapingSlashes])
    }

    private func transformJSON(options: JSONSerialization.WritingOptions) {
        do {
            let result = try JSONFormatterEngine.transform(inputText, options: options)
            outputText = result
            errorMessage = nil
            searchTarget = .output
            saveHistory(formattedJSON: result)
        } catch {
            outputText = ""
            errorMessage = JSONFormatterEngine.message(for: error)
        }
    }

    private func saveHistory(formattedJSON: String) {
        let rawJSON = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = histories.first(where: { $0.rawJSON == rawJSON }) {
            existing.update(rawJSON: rawJSON, formattedJSON: formattedJSON)
        } else {
            modelContext.insert(JSONFormatHistory(rawJSON: rawJSON, formattedJSON: formattedJSON))
        }

        do {
            try modelContext.save()
            try pruneHistory()
        } catch {
            assertionFailure("Failed to save JSON history: \(error)")
        }
    }

    private func pruneHistory() throws {
        var descriptor = FetchDescriptor<JSONFormatHistory>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        let allHistories = try modelContext.fetch(descriptor)
        for history in allHistories.dropFirst(50) {
            modelContext.delete(history)
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    private func restore(_ history: JSONFormatHistory) {
        replaceInputText(history.rawJSON, actionName: "恢复历史")
        outputText = history.formattedJSON
        errorMessage = nil
        searchTarget = .output
        showsHistory = false
        JSONFormatterDraftStore.save(history.rawJSON)
    }

    private func clear() {
        replaceInputText("", actionName: "清空")
        outputText = ""
        errorMessage = nil
        copiedOutput = false
        JSONFormatterDraftStore.clear()
    }

    private func replaceInputText(_ text: String, actionName: String) {
        if !inputEditingState.replaceAllText(with: text, actionName: actionName) {
            inputText = text
        }
    }

    private func clampedResultPaneRatio(_ ratio: Double) -> Double {
        min(max(ratio, Layout.minResultPaneRatio), Layout.maxResultPaneRatio)
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        let target = searchTarget == .output && outputText.isEmpty ? JSONSearchTarget.input : searchTarget
        let request = JSONTextSearchRequest(query: query)
        searchStatus = "搜索中..."

        switch target {
        case .input:
            inputSearchRequest = request
        case .output:
            outputSearchRequest = request
        }
    }

    private func updateSearchStatus(_ result: JSONTextSearchResult?, target: JSONSearchTarget) {
        guard let result else { return }
        guard target == searchTarget || (searchTarget == .output && outputText.isEmpty && target == .input) else { return }

        if result.isFound {
            searchStatus = "\(target.title) \(result.matchIndex)/\(result.totalMatches)  行 \(result.line), 列 \(result.column)"
        } else {
            searchStatus = "未找到"
        }
    }

    private func copyOutput() {
        guard !outputText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
        copiedOutput = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copiedOutput = false
        }
    }
}

private enum JSONToolMode: String, CaseIterable, Identifiable {
    case format
    case compare

    var id: String { rawValue }

    var pickerTitle: String {
        switch self {
        case .format:
            "格式化"
        case .compare:
            "比对"
        }
    }

    var title: String {
        switch self {
        case .format:
            "JSON 格式化"
        case .compare:
            "JSON 比对"
        }
    }

    var subtitle: String {
        switch self {
        case .format:
            "格式化、压缩并保存最近 50 条记录"
        case .compare:
            "结构化比对两段 JSON 的差异"
        }
    }
}

private enum JSONSearchTarget: String, CaseIterable, Identifiable {
    case input
    case output

    var id: String { rawValue }

    var title: String {
        switch self {
        case .input:
            "输入"
        case .output:
            "结果"
        }
    }
}

private enum JSONFormatterDraftStore {
    private static let textKey = "jsonFormatterDraftText"
    private static let savedAtKey = "jsonFormatterDraftSavedAt"
    private static let lifetime: TimeInterval = 60

    static func loadFreshDraft(now: Date = Date()) -> String? {
        let defaults = UserDefaults.standard
        guard let savedAt = defaults.object(forKey: savedAtKey) as? Date else { return nil }

        guard now.timeIntervalSince(savedAt) <= lifetime else {
            clear()
            return nil
        }

        return defaults.string(forKey: textKey)
    }

    static func save(_ text: String, now: Date = Date()) {
        let defaults = UserDefaults.standard
        defaults.set(text, forKey: textKey)
        defaults.set(now, forKey: savedAtKey)
    }

    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: textKey)
        defaults.removeObject(forKey: savedAtKey)
    }
}
