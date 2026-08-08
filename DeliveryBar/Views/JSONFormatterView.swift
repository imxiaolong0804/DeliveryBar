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
        // 窗口可缩放，这里只给下限，实际尺寸跟随窗口
        static let minWidth: CGFloat = 720
        static let minHeight: CGFloat = 460
        static let historyWidth: CGFloat = 230
        static let editorMinWidth: CGFloat = 180
        static let splitHandleThickness: CGFloat = 14
        static let splitHandleLength: CGFloat = 40
        static let minResultPaneRatio = 0.25
        static let maxResultPaneRatio = 0.85
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
    @State private var showsSearch = false
    @State private var copiedOutput = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var searchTarget: JSONSearchTarget = .output
    @State private var searchStatus: String?
    @State private var inputSearchRequest: JSONTextSearchRequest?
    @State private var outputSearchRequest: JSONTextSearchRequest?
    @State private var inputSearchResult: JSONTextSearchResult?
    @State private var outputSearchResult: JSONTextSearchResult?
    @StateObject private var inputEditingState = JSONTextEditingState()
    @StateObject private var outputEditingState = JSONTextEditingState()
    // 换了 key：语义从"结果区高度占比"变成"宽度占比"，沿用旧值会让分栏位置莫名其妙。
    // 默认 0.62 而不是对半分——结果区才是要看的东西，输入区够粘贴就行。
    @AppStorage("jsonFormatterResultPaneWidthRatio") private var resultPaneRatio = 0.62
    @AppStorage("jsonEditorFontSize") private var editorFontSize = Double(JSONSyntaxTheme.defaultFontSize)

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
                if showsSearch {
                    searchBar
                }

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
        .frame(minWidth: Layout.minWidth, maxWidth: .infinity, minHeight: Layout.minHeight, maxHeight: .infinity)
        .background(DeliveryBarTheme.panelBackground)
        .tint(DeliveryBarTheme.accent)
        .onChange(of: inputText) { _, newValue in
            JSONFormatterDraftStore.scheduleSave(newValue)
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
        HStack(spacing: 8) {
            Image(systemName: "curlybraces")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DeliveryBarTheme.inkSoft)
                .frame(width: 26, height: 26)
                .background(DeliveryBarTheme.quietFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(mode.title)
                .font(DeliveryBarTheme.Typography.windowTitle)
                .foregroundStyle(DeliveryBarTheme.ink)

            Spacer()

            Picker("", selection: $mode) {
                ForEach(JSONToolMode.allCases) { mode in
                    Text(mode.pickerTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 124)

            if mode == .format {
                ChromeButton(
                    systemImage: "magnifyingglass",
                    isActive: showsSearch,
                    shortcut: "f",
                    help: "搜索 (⌘F)"
                ) {
                    toggleSearch()
                }

                ChromeButton(
                    systemImage: "clock.arrow.circlepath",
                    isActive: showsHistory,
                    help: "格式化历史"
                ) {
                    showsHistory.toggle()
                }
            }

            ChromeButton(
                systemImage: isPinned ? "pin.fill" : "pin",
                isActive: isPinned,
                help: "窗口保持在最前"
            ) {
                isPinned.toggle()
            }

            ChromeButton(systemImage: "xmark", help: "关闭") {
                onClose()
            }
        }
        .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
        .padding(.vertical, DeliveryBarTheme.Spacing.md)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(DeliveryBarTheme.softText)

            TextField("搜索 JSON 内容，回车跳到下一处", text: $searchText)
                .textFieldStyle(.plain)
                .font(DeliveryBarTheme.Typography.callout)
                .focused($isSearchFocused)
                .onSubmit {
                    performSearch()
                }

            if let searchStatus {
                Text(searchStatus)
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .lineLimit(1)
            }

            Picker("", selection: $searchTarget) {
                ForEach(JSONSearchTarget.allCases) { target in
                    Text(target.title).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 96)

            ChromeButton(systemImage: "xmark", help: "关闭搜索") {
                toggleSearch()
            }
        }
        .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
        .padding(.bottom, DeliveryBarTheme.Spacing.sm)
    }

    private func toggleSearch() {
        withAnimation(.snappy(duration: 0.16)) {
            showsSearch.toggle()
        }

        guard showsSearch else {
            searchStatus = nil
            return
        }

        // 输入框这一帧才挂上去，等一个渲染回合再抢焦点
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private var formatterContent: some View {
        GeometryReader { proxy in
            splitEditorContent(availableWidth: proxy.size.width)
        }
        .padding(DeliveryBarTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 左右分栏而不是上下：JSON 是逐字段对照着看的，横向并排才能一眼对上，
    /// 上下叠着要来回滚。宽度默认偏向结果区。
    private func splitEditorContent(availableWidth: CGFloat) -> some View {
        let paneWidth = max(1, availableWidth - Layout.splitHandleThickness)
        let minPaneWidth = min(Layout.editorMinWidth, paneWidth / 2)
        let rawResultWidth = paneWidth * CGFloat(clampedResultPaneRatio(resultPaneRatio))
        let resultWidth = min(max(rawResultWidth, minPaneWidth), paneWidth - minPaneWidth)
        let inputWidth = paneWidth - resultWidth

        return HStack(spacing: 0) {
            inputPane
                .frame(width: inputWidth)

            splitHandle(paneWidth: paneWidth)

            outputPane
                .frame(width: resultWidth)
        }
    }

    private var inputPane: some View {
        editorPane(title: "原始内容", isPrimary: false, characterCount: inputText.count) {
            EmptyView()
        } content: {
            SearchableJSONTextView(
                text: $inputText,
                isEditable: true,
                searchRequest: inputSearchRequest,
                searchResult: $inputSearchResult,
                editingState: inputEditingState,
                fontSize: CGFloat(editorFontSize)
            )
        }
    }

    private var outputPane: some View {
        editorPane(title: "格式化结果", isPrimary: true, characterCount: outputText.count) {
            fontSizeControls
        } content: {
            SearchableJSONTextView(
                text: $outputText,
                isEditable: true,
                searchRequest: outputSearchRequest,
                searchResult: $outputSearchResult,
                editingState: outputEditingState,
                fontSize: CGFloat(editorFontSize)
            )
            .overlay {
                if outputText.isEmpty {
                    Text("格式化后的结果显示在这里")
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(DeliveryBarTheme.muted)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var fontSizeControls: some View {
        HStack(spacing: 2) {
            ChromeButton(systemImage: "textformat.size.smaller", help: "缩小字号") {
                editorFontSize = max(Double(JSONSyntaxTheme.minimumFontSize), editorFontSize - 1)
            }

            ChromeButton(systemImage: "textformat.size.larger", help: "放大字号") {
                editorFontSize = min(Double(JSONSyntaxTheme.maximumFontSize), editorFontSize + 1)
            }
        }
    }

    private func splitHandle(paneWidth: CGFloat) -> some View {
        JSONPaneSplitHandle(
            resultPaneRatio: $resultPaneRatio,
            paneLength: paneWidth,
            minRatio: Layout.minResultPaneRatio,
            maxRatio: Layout.maxResultPaneRatio,
            handleLength: Layout.splitHandleLength,
            isHorizontal: true
        )
        .frame(width: Layout.splitHandleThickness)
        .frame(maxHeight: .infinity)
        .help("拖动调整两栏宽度")
        .accessibilityLabel("调整两栏宽度")
    }

    /// 两栏的主次靠三件事拉开：宽度、标题层级、底色深浅。
    /// 结果区标题是窗口级字号、底色更实；输入区退成小标题、底色更淡。
    private func editorPane<Accessory: View, Content: View>(
        title: String,
        isPrimary: Bool,
        characterCount: Int,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DeliveryBarTheme.Spacing.md) {
                Text(title)
                    .font(isPrimary ? DeliveryBarTheme.Typography.windowTitle : DeliveryBarTheme.Typography.captionStrong)
                    .foregroundStyle(isPrimary ? DeliveryBarTheme.ink : DeliveryBarTheme.softText)
                    .lineLimit(1)

                Spacer(minLength: DeliveryBarTheme.Spacing.xs)

                Text("\(characterCount) 字符")
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.muted)
                    .monospacedDigit()
                    .lineLimit(1)

                accessory()
            }
            .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
            .padding(.vertical, DeliveryBarTheme.Spacing.md)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(editorBackground(isPrimary: isPrimary))
        .clipShape(RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous))
    }

    /// 给代码区垫一层底，让它从毛玻璃面板上"凹"下去——参考图里那种纯净代码区的观感
    /// 靠的就是这层底。结果区比输入区更实一档。
    private func editorBackground(isPrimary: Bool) -> Color {
        .dynamic(
            light: .white.withAlphaComponent(isPrimary ? 0.55 : 0.28),
            dark: .black.withAlphaComponent(isPrimary ? 0.30 : 0.16)
        )
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("历史")
                    .font(DeliveryBarTheme.Typography.captionStrong)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Spacer()

                Text("\(histories.count)")
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
            }
            .padding(DeliveryBarTheme.Spacing.lg)

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
                    .padding(DeliveryBarTheme.Spacing.md)
                }
            }
        }
        .background(DeliveryBarTheme.quietFill)
    }

    private func historyRow(_ history: JSONFormatHistory) -> some View {
        Button {
            restore(history)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(history.summary)
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.ink)
                    .lineLimit(3)

                Text(DateUtils.relativeUpdateText(for: history.updatedAt))
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .deliveryCard(padding: 8)
            .hoverHighlight(cornerRadius: DeliveryBarTheme.Radius.card)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("复制原文") { Clipboard.copy(history.rawJSON) }
            Button("复制格式化结果") { Clipboard.copy(history.formattedJSON) }
        }
    }

    /// 一排按钮全是图标加文字的话视觉重量一样重，看不出主次。
    /// 这里只留「格式化」一个主按钮，其余降成文字。
    private var footer: some View {
        HStack(spacing: 10) {
            Button("清空") {
                clear()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(DeliveryBarTheme.softText)

            // 报错放这儿而不是结果区上方：那里一出现就会把编辑器往下顶，布局跟着跳
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.danger)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(errorMessage)
            }

            Spacer(minLength: 8)

            Button("压缩") {
                compress()
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(copiedOutput ? "已复制" : "复制结果") {
                copyOutput()
            }
            .disabled(outputText.isEmpty)

            Button("格式化") {
                format()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
        .padding(.vertical, DeliveryBarTheme.Spacing.md)
    }

    private var diffFooter: some View {
        HStack(spacing: 10) {
            Button("清空") {
                clearDiff()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(DeliveryBarTheme.softText)

            Spacer(minLength: 8)

            Button("交换左右") {
                swapDiffSides()
            }
            .disabled(diffLeftText.isEmpty && diffRightText.isEmpty)

            Button("比对") {
                runDiff()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canRunDiff)
        }
        .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
        .padding(.vertical, DeliveryBarTheme.Spacing.md)
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
        transformJSON(prettyPrinted: true)
    }

    private func compress() {
        transformJSON(prettyPrinted: false)
    }

    private func transformJSON(prettyPrinted: Bool) {
        do {
            let result = try JSONFormatterEngine.transform(inputText, prettyPrinted: prettyPrinted)
            replaceOutputText(result, actionName: prettyPrinted ? "格式化" : "压缩")
            errorMessage = nil
            searchTarget = .output
            saveHistory(formattedJSON: result)
        } catch {
            replaceOutputText("", actionName: "清空结果")
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
        replaceOutputText(history.formattedJSON, actionName: "恢复历史")
        errorMessage = nil
        searchTarget = .output
        showsHistory = false
        JSONFormatterDraftStore.save(history.rawJSON)
    }

    private func clear() {
        replaceInputText("", actionName: "清空")
        replaceOutputText("", actionName: "清空")
        errorMessage = nil
        copiedOutput = false
        JSONFormatterDraftStore.clear()
    }

    private func replaceInputText(_ text: String, actionName: String) {
        if !inputEditingState.replaceAllText(with: text, actionName: actionName) {
            inputText = text
        }
    }

    /// 走编辑状态而不是直接改 @State：这样程序写入也进撤销栈，
    /// 用户手动改过结果后再点格式化，⌘Z 能回到改之前
    private func replaceOutputText(_ text: String, actionName: String) {
        if !outputEditingState.replaceAllText(with: text, actionName: actionName, caretAtStart: true) {
            outputText = text
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
        Clipboard.copy(outputText)
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
    private static let writeDelay: TimeInterval = 0.6

    private static var pendingWrite: DispatchWorkItem?

    /// 输入区每敲一个字符都会触发。大段 JSON 直接写 UserDefaults 会卡输入，
    /// 所以停手 0.6 秒才真正落盘。
    static func scheduleSave(_ text: String) {
        pendingWrite?.cancel()

        let write = DispatchWorkItem { save(text) }
        pendingWrite = write
        DispatchQueue.main.asyncAfter(deadline: .now() + writeDelay, execute: write)
    }

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
        pendingWrite?.cancel()
        let defaults = UserDefaults.standard
        defaults.set(text, forKey: textKey)
        defaults.set(now, forKey: savedAtKey)
    }

    static func clear() {
        pendingWrite?.cancel()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: textKey)
        defaults.removeObject(forKey: savedAtKey)
    }
}
