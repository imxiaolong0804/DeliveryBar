//
//  JSONTextComponents.swift
//  DeliveryBar
//
//  JSON 编辑器共享组件：可搜索文本视图、撤销状态、分栏拖拽把手。
//

import AppKit
import Combine
import SwiftUI

struct JSONTextSearchRequest: Equatable {
    let id = UUID()
    let query: String
}

struct JSONTextSearchResult: Equatable {
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

struct JSONPaneSplitHandle: NSViewRepresentable {
    @Binding var resultPaneRatio: Double
    /// 分栏方向上的可用长度：左右分栏给宽度，上下分栏给高度
    let paneLength: CGFloat
    let minRatio: Double
    let maxRatio: Double
    let handleLength: CGFloat
    /// true 表示左右分栏——把手画成竖条，左右拖动
    var isHorizontal = false

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
        view.paneLength = paneLength
        view.minRatio = minRatio
        view.maxRatio = maxRatio
        view.handleLength = handleLength
        view.isHorizontal = isHorizontal
        view.needsDisplay = true
        view.window?.invalidateCursorRects(for: view)
    }

    final class SplitHandleView: NSView {
        var resultPaneRatio: Binding<Double>
        var paneLength: CGFloat = 1
        var minRatio = 0.18
        var maxRatio = 0.82
        var handleLength: CGFloat = 52
        var isHorizontal = false

        private var dragStartRatio: Double?
        private var dragStartLocation: CGFloat?

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
            dragStartLocation = isHorizontal ? event.locationInWindow.x : event.locationInWindow.y
        }

        override func mouseDragged(with event: NSEvent) {
            guard
                paneLength > 0,
                let dragStartRatio,
                let dragStartLocation
            else {
                return
            }

            let current = isHorizontal ? event.locationInWindow.x : event.locationInWindow.y
            // 结果区在右边（左右分栏）或下边（上下分栏）。往左拖 x 变小、往上拖 y 变大，
            // 两种情况下结果区都该变大，所以水平方向要取反。
            let translation = isHorizontal ? -(current - dragStartLocation) : current - dragStartLocation
            let nextRatio = dragStartRatio + Double(translation / paneLength)
            resultPaneRatio.wrappedValue = min(max(nextRatio, minRatio), maxRatio)
        }

        override func mouseUp(with event: NSEvent) {
            dragStartRatio = nil
            dragStartLocation = nil
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: isHorizontal ? .resizeLeftRight : .resizeUpDown)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            NSColor.secondaryLabelColor.withAlphaComponent(0.38).setFill()
            let handleRect = isHorizontal
                ? NSRect(x: bounds.midX - 2, y: bounds.midY - handleLength / 2, width: 4, height: handleLength)
                : NSRect(x: bounds.midX - handleLength / 2, y: bounds.midY - 2, width: handleLength, height: 4)
            NSBezierPath(roundedRect: handleRect, xRadius: 2, yRadius: 2).fill()
        }
    }
}

/// 程序写入正文的入口。走它而不是直接改 @State，是为了让「格式化」「恢复历史」这类
/// 整段替换也进系统撤销栈——用户手改过结果之后再点格式化，⌘Z 能回到改之前。
final class JSONTextEditingState: ObservableObject {
    private weak var textView: NSTextView?

    func attach(_ textView: NSTextView) {
        self.textView = textView
    }

    /// caretAtStart：格式化结果这类「换了一整份内容」的场景要停在开头，
    /// 否则会直接滚到文末，看不到刚生成的内容
    func replaceAllText(with newText: String, actionName: String, caretAtStart: Bool = false) -> Bool {
        guard let textView, textView.isEditable else { return false }

        let currentText = textView.string
        guard currentText != newText else { return true }

        let fullRange = NSRange(location: 0, length: (currentText as NSString).length)
        guard textView.shouldChangeText(in: fullRange, replacementString: newText) else { return false }

        textView.textStorage?.replaceCharacters(in: fullRange, with: newText)
        textView.didChangeText()
        textView.undoManager?.setActionName(actionName)
        textView.setSelectedRange(NSRange(location: caretAtStart ? 0 : (newText as NSString).length, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
        return true
    }
}

struct SearchableJSONTextView: NSViewRepresentable {
    @Binding var text: String
    let isEditable: Bool
    let searchRequest: JSONTextSearchRequest?
    @Binding var searchResult: JSONTextSearchResult?
    let editingState: JSONTextEditingState?
    /// 字体和行距由 JSONSyntaxHighlighter 统一打到 textStorage 上，这里只负责把值传下去
    var fontSize: CGFloat = JSONSyntaxTheme.defaultFontSize

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.font = JSONSyntaxTheme.monoFont(size: fontSize)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = isEditable
        textView.isRichText = false
        textView.importsGraphics = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width, .height]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text

        scrollView.documentView = textView

        let ruler = JSONLineNumberRuler(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.textView = textView
        context.coordinator.editingState = editingState
        context.coordinator.ruler = ruler
        context.coordinator.highlighter.fontSize = fontSize
        context.coordinator.highlighter.attach(textView)
        editingState?.attach(textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.editingState = editingState
        context.coordinator.highlighter.attach(textView)
        context.coordinator.highlighter.fontSize = fontSize
        editingState?.attach(textView)

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selectedRange.location, (text as NSString).length), length: 0))
            // 整段换内容不走 textDidChange，这里补一次着色和行号
            context.coordinator.highlighter.highlightNow()
            context.coordinator.ruler?.refresh()
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
        weak var ruler: JSONLineNumberRuler?
        let highlighter = JSONSyntaxHighlighter()
        var lastSearchRequestID: UUID?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            highlighter.schedule()
            ruler?.refresh()
        }

        /// 只为了让行号槽把当前行标出来
        func textViewDidChangeSelection(_ notification: Notification) {
            ruler?.needsDisplay = true
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
