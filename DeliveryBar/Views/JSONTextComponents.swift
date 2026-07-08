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

final class JSONTextEditingState: ObservableObject {
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

struct SearchableJSONTextView: NSViewRepresentable {
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
