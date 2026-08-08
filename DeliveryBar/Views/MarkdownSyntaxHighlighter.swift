//
//  MarkdownSyntaxHighlighter.swift
//  DeliveryBar
//
//  备忘正文的内联 Markdown 着色。
//
//  语法符号淡化但不隐藏（Bear 的路子，不是 Obsidian 那种光标离开就隐藏）：
//  源码始终可编辑、光标位置不会跳，也不用维护「光标在不在本行」的状态机。
//

import AppKit

// MARK: - Theme

enum MarkdownTextTheme {
    static let bodyFont = NSFont.systemFont(ofSize: 13.5)
    static let boldFont = NSFont.systemFont(ofSize: 13.5, weight: .semibold)
    static let monoFont = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
    static let italicFont = NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)

    static let marker = NSColor.tertiaryLabelColor
    static let quoteText = NSColor.secondaryLabelColor
    static let listMarker = NSColor.controlAccentColor
    static let codeBackground = NSColor.dynamic(
        light: .quinarySystemFill,
        dark: .white.withAlphaComponent(0.06)
    )

    static func headingFont(level: Int) -> NSFont {
        switch level {
        case 1:
            .systemFont(ofSize: 20, weight: .medium)
        case 2:
            .systemFont(ofSize: 16.5, weight: .medium)
        case 3:
            .systemFont(ofSize: 14.5, weight: .medium)
        default:
            .systemFont(ofSize: 13.5, weight: .semibold)
        }
    }

    static var bodyAttributes: [NSAttributedString.Key: Any] {
        [
            .font: bodyFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: bodyParagraphStyle
        ]
    }

    static let bodyParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.5
        style.paragraphSpacing = 6
        return style
    }()

    /// 标题靠段前距和正文拉开距离，一级二级留得多一些
    static func headingParagraphStyle(level: Int) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.25
        style.paragraphSpacingBefore = level <= 2 ? 16 : 10
        style.paragraphSpacing = 4
        return style
    }

    static let quoteParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.5
        style.firstLineHeadIndent = 12
        style.headIndent = 12
        style.paragraphSpacing = 6
        return style
    }()

    static let codeParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.3
        style.firstLineHeadIndent = 8
        style.headIndent = 8
        return style
    }()

    /// 列表项换行后和文字对齐，不要缩回行首
    static func listParagraphStyle(markerWidth: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.5
        style.headIndent = markerWidth
        style.paragraphSpacing = 2
        return style
    }
}

// MARK: - Highlighter

final class MarkdownSyntaxHighlighter {
    private static let debounce: TimeInterval = 0.12

    private weak var textView: NSTextView?
    private var pendingHighlight: DispatchWorkItem?

    func attach(_ textView: NSTextView) {
        guard self.textView !== textView else { return }
        self.textView = textView
        highlightNow()
    }

    func schedule() {
        pendingHighlight?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.highlightNow()
        }
        pendingHighlight = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounce, execute: work)
    }

    func highlightNow() {
        pendingHighlight?.cancel()
        pendingHighlight = nil

        guard let textView, let textStorage = textView.textStorage else { return }

        let source = textStorage.string
        let nsSource = source as NSString
        let fullRange = NSRange(location: 0, length: nsSource.length)

        textStorage.beginEditing()
        // setAttributes 而不是 add：顺便把上一轮的底色、删除线这些一并清掉
        textStorage.setAttributes(MarkdownTextTheme.bodyAttributes, range: fullRange)

        for line in MarkdownLineScanner.lines(in: nsSource) {
            apply(line, in: source, to: textStorage)
        }
        textStorage.endEditing()

        textView.typingAttributes = MarkdownTextTheme.bodyAttributes
    }

    private func apply(_ line: MarkdownLine, in source: String, to storage: NSTextStorage) {
        guard line.range.length > 0 else { return }

        switch line.kind {
        case let .heading(level, marker):
            storage.addAttributes(
                [
                    .font: MarkdownTextTheme.headingFont(level: level),
                    .paragraphStyle: MarkdownTextTheme.headingParagraphStyle(level: level)
                ],
                range: line.range
            )
            storage.addAttribute(.foregroundColor, value: MarkdownTextTheme.marker, range: marker)
            applySpans(in: line.range, source: source, to: storage)

        case let .bullet(marker), let .ordered(marker):
            storage.addAttribute(
                .paragraphStyle,
                value: MarkdownTextTheme.listParagraphStyle(markerWidth: CGFloat(marker.length) * 7),
                range: line.range
            )
            storage.addAttribute(.foregroundColor, value: MarkdownTextTheme.listMarker, range: marker)
            applySpans(in: line.range, source: source, to: storage)

        case let .quote(marker):
            storage.addAttributes(
                [
                    .foregroundColor: MarkdownTextTheme.quoteText,
                    .paragraphStyle: MarkdownTextTheme.quoteParagraphStyle
                ],
                range: line.range
            )
            storage.addAttribute(.foregroundColor, value: MarkdownTextTheme.marker, range: marker)

        case .codeFence:
            storage.addAttributes(
                [.font: MarkdownTextTheme.monoFont, .foregroundColor: MarkdownTextTheme.marker],
                range: line.range
            )

        case .codeBody:
            storage.addAttributes(
                [
                    .font: MarkdownTextTheme.monoFont,
                    .backgroundColor: MarkdownTextTheme.codeBackground,
                    .paragraphStyle: MarkdownTextTheme.codeParagraphStyle
                ],
                range: line.range
            )

        case .divider:
            storage.addAttribute(.foregroundColor, value: MarkdownTextTheme.marker, range: line.range)

        case .paragraph:
            applySpans(in: line.range, source: source, to: storage)
        }
    }

    private func applySpans(in lineRange: NSRange, source: String, to storage: NSTextStorage) {
        for span in MarkdownLineScanner.spans(in: source, within: lineRange) {
            let inner = NSRange(
                location: span.range.location + span.markerLength,
                length: max(0, span.range.length - span.markerLength * 2)
            )

            switch span.kind {
            case .code:
                // 底色铺满含反引号的整段，看起来才是一块，而不是两头缺角
                storage.addAttributes(
                    [.font: MarkdownTextTheme.monoFont, .backgroundColor: MarkdownTextTheme.codeBackground],
                    range: span.range
                )
            case .bold:
                storage.addAttribute(.font, value: MarkdownTextTheme.boldFont, range: inner)
            case .italic:
                storage.addAttribute(.font, value: MarkdownTextTheme.italicFont, range: inner)
            case .strikethrough:
                storage.addAttributes(
                    [
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: MarkdownTextTheme.quoteText
                    ],
                    range: inner
                )
            }

            storage.addAttribute(
                .foregroundColor,
                value: MarkdownTextTheme.marker,
                range: NSRange(location: span.range.location, length: span.markerLength)
            )
            storage.addAttribute(
                .foregroundColor,
                value: MarkdownTextTheme.marker,
                range: NSRange(location: NSMaxRange(span.range) - span.markerLength, length: span.markerLength)
            )
        }
    }
}
