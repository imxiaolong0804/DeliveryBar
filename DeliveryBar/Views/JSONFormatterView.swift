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
        }
        .frame(width: Layout.width, height: Layout.height)
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
                Text("JSON 格式化")
                    .font(.headline)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Text("格式化、压缩并保存最近 50 条记录")
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
            }

            Spacer()

            Toggle("置顶", isOn: $isPinned)
                .toggleStyle(.switch)
                .font(.caption)

            Button {
                showsHistory.toggle()
            } label: {
                Label("历史", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.bordered)

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
        .background(Color.white.opacity(0.18))
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
                background: Color.white.opacity(0.45)
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
                .padding(6)
                .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DeliveryBarTheme.cardStroke)
                }
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
        .background(Color.white.opacity(0.18))
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
            .padding(8)
            .background(DeliveryBarTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DeliveryBarTheme.cardStroke)
            }
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

private struct JSONTextSearchRequest: Equatable {
    let id = UUID()
    let query: String
}

private struct JSONTextSearchResult: Equatable {
    let query: String
    let isFound: Bool
    let line: Int
    let column: Int
    let matchIndex: Int
    let totalMatches: Int

    static func notFound(query: String) -> JSONTextSearchResult {
        JSONTextSearchResult(query: query, isFound: false, line: 0, column: 0, matchIndex: 0, totalMatches: 0)
    }
}

private struct JSONPaneSplitHandle: NSViewRepresentable {
    @Binding var resultPaneRatio: Double
    let paneHeight: CGFloat
    let minRatio: Double
    let maxRatio: Double
    let handleWidth: CGFloat

    func makeNSView(context: Context) -> SplitHandleView {
        let view = SplitHandleView(resultPaneRatio: $resultPaneRatio)
        update(view)
        return view
    }

    func updateNSView(_ nsView: SplitHandleView, context: Context) {
        nsView.resultPaneRatio = $resultPaneRatio
        update(nsView)
    }

    private func update(_ view: SplitHandleView) {
        view.paneHeight = paneHeight
        view.minRatio = minRatio
        view.maxRatio = maxRatio
        view.handleWidth = handleWidth
        view.needsDisplay = true
    }

    final class SplitHandleView: NSView {
        var resultPaneRatio: Binding<Double>
        var paneHeight: CGFloat = 1
        var minRatio = 0.18
        var maxRatio = 0.82
        var handleWidth: CGFloat = 52

        private var dragStartRatio: Double?
        private var dragStartLocationY: CGFloat?

        override var mouseDownCanMoveWindow: Bool { false }
        override var acceptsFirstResponder: Bool { true }

        init(resultPaneRatio: Binding<Double>) {
            self.resultPaneRatio = resultPaneRatio
            super.init(frame: .zero)
            wantsLayer = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func mouseDown(with event: NSEvent) {
            dragStartRatio = resultPaneRatio.wrappedValue
            dragStartLocationY = event.locationInWindow.y
        }

        override func mouseDragged(with event: NSEvent) {
            guard
                paneHeight > 0,
                let dragStartRatio,
                let dragStartLocationY
            else {
                return
            }

            let translationY = event.locationInWindow.y - dragStartLocationY
            let nextRatio = dragStartRatio + Double(translationY / paneHeight)
            resultPaneRatio.wrappedValue = min(max(nextRatio, minRatio), maxRatio)
        }

        override func mouseUp(with event: NSEvent) {
            dragStartRatio = nil
            dragStartLocationY = nil
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeUpDown)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            NSColor.secondaryLabelColor.withAlphaComponent(0.38).setFill()
            let handleRect = NSRect(
                x: bounds.midX - handleWidth / 2,
                y: bounds.midY - 2,
                width: handleWidth,
                height: 4
            )
            NSBezierPath(roundedRect: handleRect, xRadius: 2, yRadius: 2).fill()
        }
    }
}

private final class JSONTextEditingState: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private weak var textView: NSTextView?

    func attach(_ textView: NSTextView) {
        self.textView = textView
        scheduleUndoAvailabilityUpdate()
    }

    func undo() {
        guard let undoManager = textView?.undoManager, undoManager.canUndo else { return }
        undoManager.undo()
        scheduleUndoAvailabilityUpdate()
    }

    func redo() {
        guard let undoManager = textView?.undoManager, undoManager.canRedo else { return }
        undoManager.redo()
        scheduleUndoAvailabilityUpdate()
    }

    func replaceAllText(with newText: String, actionName: String) -> Bool {
        guard let textView, textView.isEditable else { return false }

        let currentText = textView.string
        guard currentText != newText else {
            scheduleUndoAvailabilityUpdate()
            return true
        }

        let fullRange = NSRange(location: 0, length: (currentText as NSString).length)
        guard textView.shouldChangeText(in: fullRange, replacementString: newText) else { return false }

        textView.textStorage?.replaceCharacters(in: fullRange, with: newText)
        textView.didChangeText()
        textView.undoManager?.setActionName(actionName)
        textView.setSelectedRange(NSRange(location: (newText as NSString).length, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
        scheduleUndoAvailabilityUpdate()
        return true
    }

    func scheduleUndoAvailabilityUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.updateUndoAvailability()
        }
    }

    private func updateUndoAvailability() {
        let nextCanUndo = textView?.undoManager?.canUndo ?? false
        let nextCanRedo = textView?.undoManager?.canRedo ?? false

        if canUndo != nextCanUndo {
            canUndo = nextCanUndo
        }
        if canRedo != nextCanRedo {
            canRedo = nextCanRedo
        }
    }
}

private struct SearchableJSONTextView: NSViewRepresentable {
    @Binding var text: String
    let isEditable: Bool
    let searchRequest: JSONTextSearchRequest?
    @Binding var searchResult: JSONTextSearchResult?
    let editingState: JSONTextEditingState?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = isEditable
        textView.isRichText = false
        textView.importsGraphics = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width, .height]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.editingState = editingState
        editingState?.attach(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.editingState = editingState
        editingState?.attach(textView)

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selectedRange.location, (text as NSString).length), length: 0))
            editingState?.scheduleUndoAvailabilityUpdate()
        }

        textView.isEditable = isEditable

        if let searchRequest, context.coordinator.lastSearchRequestID != searchRequest.id {
            context.coordinator.lastSearchRequestID = searchRequest.id
            let result = context.coordinator.search(query: searchRequest.query)
            DispatchQueue.main.async {
                searchResult = result
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        weak var editingState: JSONTextEditingState?
        var lastSearchRequestID: UUID?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            editingState?.scheduleUndoAvailabilityUpdate()
        }

        func search(query: String) -> JSONTextSearchResult {
            guard let textView else { return .notFound(query: query) }

            let source = textView.string as NSString
            let totalLength = source.length
            guard totalLength > 0 else { return .notFound(query: query) }

            let totalMatches = countMatches(query: query, in: source)
            guard totalMatches > 0 else { return .notFound(query: query) }

            let selectedRange = textView.selectedRange()
            let startLocation = min(selectedRange.location + max(selectedRange.length, 1), totalLength)
            let firstRange = NSRange(location: startLocation, length: totalLength - startLocation)
            var foundRange = source.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: firstRange)

            if foundRange.location == NSNotFound {
                foundRange = source.range(
                    of: query,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: NSRange(location: 0, length: totalLength)
                )
            }

            guard foundRange.location != NSNotFound else { return .notFound(query: query) }

            textView.setSelectedRange(foundRange)
            textView.scrollRangeToVisible(foundRange)
            textView.window?.makeFirstResponder(textView)

            let position = lineAndColumn(for: foundRange.location, in: source)
            let matchIndex = matchIndexForRange(foundRange, query: query, in: source)
            return JSONTextSearchResult(
                query: query,
                isFound: true,
                line: position.line,
                column: position.column,
                matchIndex: matchIndex,
                totalMatches: totalMatches
            )
        }

        private func countMatches(query: String, in source: NSString) -> Int {
            var count = 0
            var searchRange = NSRange(location: 0, length: source.length)

            while searchRange.length > 0 {
                let range = source.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
                guard range.location != NSNotFound else { break }
                count += 1

                let nextLocation = range.location + max(range.length, 1)
                searchRange = NSRange(location: nextLocation, length: source.length - nextLocation)
            }

            return count
        }

        private func matchIndexForRange(_ targetRange: NSRange, query: String, in source: NSString) -> Int {
            var index = 0
            var searchRange = NSRange(location: 0, length: source.length)

            while searchRange.length > 0 {
                let range = source.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
                guard range.location != NSNotFound else { break }
                index += 1

                if range.location == targetRange.location {
                    return index
                }

                let nextLocation = range.location + max(range.length, 1)
                searchRange = NSRange(location: nextLocation, length: source.length - nextLocation)
            }

            return max(index, 1)
        }

        private func lineAndColumn(for location: Int, in source: NSString) -> (line: Int, column: Int) {
            var line = 1
            var column = 1
            var index = 0
            let target = min(location, source.length)

            while index < target {
                let character = source.character(at: index)
                if character == 10 || character == 13 {
                    line += 1
                    column = 1

                    if character == 13, index + 1 < target, source.character(at: index + 1) == 10 {
                        index += 1
                    }
                } else {
                    column += 1
                }

                index += 1
            }

            return (line, column)
        }
    }
}

private enum JSONFormatterEngine {
    static func transform(_ text: String, options: JSONSerialization.WritingOptions) throws -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = try OrderedJSONParser(text: normalized).parse()
        return OrderedJSONRenderer.render(value, prettyPrinted: options.contains(.prettyPrinted))
    }

    static func message(for error: Error) -> String {
        if let formatterError = error as? JSONFormatterError {
            return formatterError.localizedDescription
        }

        if let parseError = error as? OrderedJSONParseError {
            return parseError.localizedDescription
        }

        let nsError = error as NSError
        if let debugDescription = nsError.userInfo["NSDebugDescription"] as? String {
            return debugDescription
        }

        return nsError.localizedDescription
    }
}

private enum OrderedJSONValue {
    case object([(key: String, value: OrderedJSONValue)])
    case array([OrderedJSONValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null
}

private struct OrderedJSONParseError: LocalizedError {
    let message: String
    let line: Int
    let column: Int

    var errorDescription: String? {
        "第 \(line) 行，第 \(column) 列：\(message)"
    }
}

private final class OrderedJSONParser {
    private let text: String
    private var index: String.Index
    private var line = 1
    private var column = 1

    init(text: String) {
        self.text = text
        self.index = text.startIndex
    }

    func parse() throws -> OrderedJSONValue {
        skipWhitespace()
        guard !isAtEnd else {
            throw makeError("请输入 JSON 内容")
        }

        let value = try parseValue()
        skipWhitespace()

        guard isAtEnd else {
            throw makeError("JSON 末尾存在多余内容")
        }

        return value
    }

    private var isAtEnd: Bool {
        index >= text.endIndex
    }

    private var currentCharacter: Character? {
        isAtEnd ? nil : text[index]
    }

    private func parseValue() throws -> OrderedJSONValue {
        skipWhitespace()

        guard let character = currentCharacter else {
            throw makeError("JSON 内容不完整")
        }

        switch character {
        case "{":
            return try parseObject()
        case "[":
            return try parseArray()
        case "\"":
            return try .string(parseString())
        case "-", "0"..."9":
            return try .number(parseNumber())
        case "t":
            try consumeLiteral("true")
            return .bool(true)
        case "f":
            try consumeLiteral("false")
            return .bool(false)
        case "n":
            try consumeLiteral("null")
            return .null
        default:
            throw makeError("无法识别的 JSON 值")
        }
    }

    private func parseObject() throws -> OrderedJSONValue {
        try consume("{")
        skipWhitespace()

        var entries: [(key: String, value: OrderedJSONValue)] = []
        if currentCharacter == "}" {
            advance()
            return .object(entries)
        }

        while true {
            skipWhitespace()
            guard currentCharacter == "\"" else {
                throw makeError("对象 key 必须是字符串")
            }

            let key = try parseString()
            skipWhitespace()
            try consume(":")
            let value = try parseValue()
            entries.append((key, value))
            skipWhitespace()

            if currentCharacter == "}" {
                advance()
                return .object(entries)
            }

            try consume(",")
        }
    }

    private func parseArray() throws -> OrderedJSONValue {
        try consume("[")
        skipWhitespace()

        var values: [OrderedJSONValue] = []
        if currentCharacter == "]" {
            advance()
            return .array(values)
        }

        while true {
            values.append(try parseValue())
            skipWhitespace()

            if currentCharacter == "]" {
                advance()
                return .array(values)
            }

            try consume(",")
        }
    }

    private func parseString() throws -> String {
        try consume("\"")

        var result = ""
        while let character = currentCharacter {
            switch character {
            case "\"":
                advance()
                return result
            case "\\":
                advance()
                result.append(try parseEscapedCharacter())
            default:
                guard !character.unicodeScalars.contains(where: { $0.value < 0x20 }) else {
                    throw makeError("字符串中存在未转义的控制字符")
                }

                result.append(character)
                advance()
            }
        }

        throw makeError("字符串没有闭合")
    }

    private func parseEscapedCharacter() throws -> String {
        guard let character = currentCharacter else {
            throw makeError("转义字符不完整")
        }

        advance()
        switch character {
        case "\"":
            return "\""
        case "\\":
            return "\\"
        case "/":
            return "/"
        case "b":
            return "\u{08}"
        case "f":
            return "\u{0C}"
        case "n":
            return "\n"
        case "r":
            return "\r"
        case "t":
            return "\t"
        case "u":
            return try parseUnicodeEscape()
        default:
            throw makeError("不支持的转义字符 \\ \(character)")
        }
    }

    private func parseUnicodeEscape() throws -> String {
        let firstValue = try parseFourHexDigits()

        if (0xD800...0xDBFF).contains(firstValue) {
            let scalarStart = lineAndColumn()
            guard currentCharacter == "\\" else {
                throw OrderedJSONParseError(message: "高位代理项缺少低位代理项", line: scalarStart.line, column: scalarStart.column)
            }

            advance()
            guard currentCharacter == "u" else {
                throw makeError("高位代理项后必须跟随 \\u")
            }

            advance()
            let secondValue = try parseFourHexDigits()
            guard (0xDC00...0xDFFF).contains(secondValue) else {
                throw makeError("低位代理项无效")
            }

            let codePoint = 0x10000 + ((firstValue - 0xD800) << 10) + (secondValue - 0xDC00)
            guard let scalar = UnicodeScalar(codePoint) else {
                throw makeError("Unicode 转义无效")
            }

            return String(scalar)
        }

        guard !(0xDC00...0xDFFF).contains(firstValue) else {
            throw makeError("低位代理项不能单独出现")
        }

        guard let scalar = UnicodeScalar(firstValue) else {
            throw makeError("Unicode 转义无效")
        }

        return String(scalar)
    }

    private func parseFourHexDigits() throws -> UInt32 {
        var value: UInt32 = 0

        for _ in 0..<4 {
            guard let character = currentCharacter, let digit = character.hexValue else {
                throw makeError("Unicode 转义必须包含 4 位十六进制数字")
            }

            value = value * 16 + UInt32(digit)
            advance()
        }

        return value
    }

    private func parseNumber() throws -> String {
        let start = index

        if currentCharacter == "-" {
            advance()
        }

        guard let integerStart = currentCharacter else {
            throw makeError("数字不完整")
        }

        if integerStart == "0" {
            advance()
            if let next = currentCharacter, next.isDigit {
                throw makeError("数字不能以 0 开头")
            }
        } else if integerStart.isDigitOneToNine {
            advanceDigits()
        } else {
            throw makeError("数字格式无效")
        }

        if currentCharacter == "." {
            advance()
            guard let firstFraction = currentCharacter, firstFraction.isDigit else {
                throw makeError("小数点后必须有数字")
            }
            advanceDigits()
        }

        if currentCharacter == "e" || currentCharacter == "E" {
            advance()

            if currentCharacter == "+" || currentCharacter == "-" {
                advance()
            }

            guard let firstExponent = currentCharacter, firstExponent.isDigit else {
                throw makeError("指数部分必须有数字")
            }
            advanceDigits()
        }

        return String(text[start..<index])
    }

    private func advanceDigits() {
        while let character = currentCharacter, character.isDigit {
            advance()
        }
    }

    private func consumeLiteral(_ literal: String) throws {
        for expected in literal {
            try consume(expected)
        }
    }

    private func consume(_ expected: Character) throws {
        guard currentCharacter == expected else {
            throw makeError("期望出现 \(expected)")
        }

        advance()
    }

    private func skipWhitespace() {
        while let character = currentCharacter, character.isJSONWhitespace {
            advance()
        }
    }

    @discardableResult
    private func advance() -> Character? {
        guard !isAtEnd else { return nil }

        let character = text[index]
        index = text.index(after: index)

        if character == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }

        return character
    }

    private func makeError(_ message: String) -> OrderedJSONParseError {
        OrderedJSONParseError(message: message, line: line, column: column)
    }

    private func lineAndColumn() -> (line: Int, column: Int) {
        (line, column)
    }
}

private enum OrderedJSONRenderer {
    static func render(_ value: OrderedJSONValue, prettyPrinted: Bool) -> String {
        render(value, prettyPrinted: prettyPrinted, depth: 0)
    }

    private static func render(_ value: OrderedJSONValue, prettyPrinted: Bool, depth: Int) -> String {
        switch value {
        case .object(let entries):
            renderObject(entries, prettyPrinted: prettyPrinted, depth: depth)
        case .array(let values):
            renderArray(values, prettyPrinted: prettyPrinted, depth: depth)
        case .string(let string):
            escapedString(string)
        case .number(let number):
            number
        case .bool(let bool):
            bool ? "true" : "false"
        case .null:
            "null"
        }
    }

    private static func renderObject(
        _ entries: [(key: String, value: OrderedJSONValue)],
        prettyPrinted: Bool,
        depth: Int
    ) -> String {
        guard !entries.isEmpty else { return "{}" }

        if !prettyPrinted {
            return "{"
                + entries
                    .map { escapedString($0.key) + ":" + render($0.value, prettyPrinted: false, depth: depth + 1) }
                    .joined(separator: ",")
                + "}"
        }

        let childIndent = indent(depth + 1)
        let currentIndent = indent(depth)
        let body = entries
            .map { childIndent + escapedString($0.key) + ": " + render($0.value, prettyPrinted: true, depth: depth + 1) }
            .joined(separator: ",\n")

        return "{\n\(body)\n\(currentIndent)}"
    }

    private static func renderArray(_ values: [OrderedJSONValue], prettyPrinted: Bool, depth: Int) -> String {
        guard !values.isEmpty else { return "[]" }

        if !prettyPrinted {
            return "[" + values.map { render($0, prettyPrinted: false, depth: depth + 1) }.joined(separator: ",") + "]"
        }

        let childIndent = indent(depth + 1)
        let currentIndent = indent(depth)
        let body = values
            .map { childIndent + render($0, prettyPrinted: true, depth: depth + 1) }
            .joined(separator: ",\n")

        return "[\n\(body)\n\(currentIndent)]"
    }

    private static func escapedString(_ value: String) -> String {
        var result = "\""

        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x08:
                result += "\\b"
            case 0x09:
                result += "\\t"
            case 0x0A:
                result += "\\n"
            case 0x0C:
                result += "\\f"
            case 0x0D:
                result += "\\r"
            case 0x22:
                result += "\\\""
            case 0x5C:
                result += "\\\\"
            case 0x00...0x1F:
                result += String(format: "\\u%04X", scalar.value)
            default:
                result.append(String(scalar))
            }
        }

        result += "\""
        return result
    }

    private static func indent(_ depth: Int) -> String {
        String(repeating: "  ", count: depth)
    }
}

private extension Character {
    var isJSONWhitespace: Bool {
        self == " " || self == "\n" || self == "\r" || self == "\t"
    }

    var isDigit: Bool {
        ("0"..."9").contains(self)
    }

    var isDigitOneToNine: Bool {
        ("1"..."9").contains(self)
    }

    var hexValue: Int? {
        guard unicodeScalars.count == 1, let scalar = unicodeScalars.first else { return nil }

        switch scalar.value {
        case 48...57:
            return Int(scalar.value - 48)
        case 65...70:
            return Int(scalar.value - 55)
        case 97...102:
            return Int(scalar.value - 87)
        default:
            return nil
        }
    }
}

private enum JSONFormatterError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            "无法按 UTF-8 读取或输出这段 JSON"
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
