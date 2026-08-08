//
//  JSONSyntaxHighlighter.swift
//  DeliveryBar
//
//  JSON 编辑区的语义着色与行号槽。
//

import AppKit

// MARK: - Theme

enum JSONSyntaxTheme {
    static let plain = NSColor.labelColor

    /// 等宽字号可调（顶栏 A- / A+），下限 11 上限 20
    static let minimumFontSize: CGFloat = 11
    static let maximumFontSize: CGFloat = 20
    static let defaultFontSize: CGFloat = 14

    static func color(for kind: JSONTokenKind) -> NSColor {
        switch kind {
        case .key:
            key
        case .string:
            string
        case .number:
            number
        case .boolean:
            boolean
        case .null:
            null
        case .punctuation:
            punctuation
        }
    }

    // 深色是照参考图取的值（GitHub Dark / One Dark 那一脉）；
    // 浅色保持同样的色相分工——key 蓝 / string 绿 / number 橙 / bool 粉 / null 紫，
    // 只是换成亮底下能读的深版本，这样明暗切换时"哪个颜色代表什么"不用重新学。
    private static let key = dynamic(light: 0x0550AE, dark: 0x79B8FF)
    private static let string = dynamic(light: 0x116329, dark: 0x7EE787)
    private static let number = dynamic(light: 0x953800, dark: 0xF0883E)
    private static let boolean = dynamic(light: 0xA40E26, dark: 0xFF7B9D)
    private static let null = dynamic(light: 0x6639BA, dark: 0xB392F0)
    private static let punctuation = dynamic(light: 0x6E7781, dark: 0x8B949E)

    static func baseAttributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: monoFont(size: fontSize),
            .foregroundColor: plain,
            .paragraphStyle: paragraphStyle
        ]
    }

    static func monoFont(size: CGFloat) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// null 单独走斜体，和 true / false 拉开——扫一眼就知道这里是空值而不是布尔
    static func italicMonoFont(size: CGFloat) -> NSFont {
        NSFontManager.shared.convert(monoFont(size: size), toHaveTrait: .italicFontMask)
    }

    private static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.45
        return style
    }()

    /// 存进 NSTextStorage 的是这个 NSColor 对象本身，绘制时才按当前外观解析，
    /// 所以明暗切换不用重新着色
    private static func dynamic(light: UInt32, dark: UInt32) -> NSColor {
        .dynamic(light: .hex(light), dark: .hex(dark))
    }
}

// MARK: - Highlighter

final class JSONSyntaxHighlighter {
    /// 每敲一个字符全量重扫会拖住输入，停手才真正着色
    private static let debounce: TimeInterval = 0.12

    private weak var textView: NSTextView?
    private var pendingHighlight: DispatchWorkItem?

    /// 顶栏 A- / A+ 调的就是它。字号变了要整段重打属性，所以直接触发一次着色。
    var fontSize = JSONSyntaxTheme.defaultFontSize {
        didSet {
            guard fontSize != oldValue else { return }
            highlightNow()
        }
    }

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

        let source = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let base = JSONSyntaxTheme.baseAttributes(fontSize: fontSize)

        textStorage.beginEditing()
        // setAttributes 而不是 add：字号变化时旧字体也要一并换掉
        textStorage.setAttributes(base, range: fullRange)
        for token in JSONTokenizer.tokens(in: source) {
            textStorage.addAttribute(.foregroundColor, value: JSONSyntaxTheme.color(for: token.kind), range: token.range)
            if token.kind == .null {
                textStorage.addAttribute(.font, value: JSONSyntaxTheme.italicMonoFont(size: fontSize), range: token.range)
            }
        }
        textStorage.endEditing()

        // 不重置的话新敲的字符会继承光标左边那个 token 的颜色，等防抖结束前一直是错的
        textView.typingAttributes = base
    }
}

// MARK: - Line number ruler

final class JSONLineNumberRuler: NSRulerView {
    private enum Layout {
        static let horizontalPadding: CGFloat = 8
        static let minimumDigits = 2
    }

    /// 每行起始的 UTF-16 下标。绘制时二分查找，避免每帧从头数换行符。
    private var lineStarts: [Int] = [0]
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)

    init(textView: NSTextView, scrollView: NSScrollView) {
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        refresh()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBoundsChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// 和 NSTextView 同向，这样 line fragment 的 y 可以直接用
    override var isFlipped: Bool { true }

    /// 默认实现会拿 controlBackgroundColor 填一层不透明底，把面板的毛玻璃挡掉。
    /// 我们不用标尺 marker，跳过 super 只画行号就行。
    override func draw(_ dirtyRect: NSRect) {
        drawHashMarksAndLabels(in: dirtyRect)
    }

    /// 正文变了或选区动了都调它：重算行首表、按位数调宽度、重绘
    func refresh() {
        recomputeLineStarts()
        updateThickness()
        needsDisplay = true
    }

    @objc private func handleBoundsChange() {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView = clientView as? NSTextView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer,
            let visibleRect = scrollView?.contentView.bounds
        else { return }

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let originY = convert(NSPoint.zero, from: textView).y + textView.textContainerOrigin.y
        let currentLine = lineNumber(containing: textView.selectedRange().location)
        let availableWidth = ruleThickness - Layout.horizontalPadding * 2

        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { _, usedRect, _, glyphRange, _ in
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)

            // 软换行的续行拿不到行首下标，直接跳过，不重复标号
            guard let number = self.lineNumber(startingAt: characterIndex) else { return }

            let label = NSAttributedString(
                string: "\(number)",
                attributes: [
                    .font: self.font,
                    .foregroundColor: number == currentLine ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor
                ]
            )

            let size = label.size()
            label.draw(
                at: NSPoint(
                    x: Layout.horizontalPadding + max(0, availableWidth - size.width),
                    y: originY + usedRect.minY + (usedRect.height - size.height) / 2
                )
            )
        }
    }

    private func recomputeLineStarts() {
        guard let textView = clientView as? NSTextView else { return }

        let source = textView.string as NSString
        let length = source.length
        var starts = [0]
        var index = 0

        while index < length {
            let character = source.character(at: index)
            if character == 0x0A {
                starts.append(index + 1)
            } else if character == 0x0D {
                // \r\n 只算一次换行
                if index + 1 < length, source.character(at: index + 1) == 0x0A {
                    index += 1
                }
                starts.append(index + 1)
            }
            index += 1
        }

        lineStarts = starts
    }

    private func updateThickness() {
        let digits = max(Layout.minimumDigits, String(lineStarts.count).count)
        let digitWidth = NSAttributedString(string: "0", attributes: [.font: font]).size().width
        let width = ceil(CGFloat(digits) * digitWidth) + Layout.horizontalPadding * 2

        if abs(ruleThickness - width) > 0.5 {
            ruleThickness = width
        }
    }

    /// 只有逻辑行首才返回行号，否则是软换行的续行
    private func lineNumber(startingAt characterIndex: Int) -> Int? {
        var low = 0
        var high = lineStarts.count - 1

        while low <= high {
            let mid = (low + high) / 2
            if lineStarts[mid] == characterIndex {
                return mid + 1
            }
            if lineStarts[mid] < characterIndex {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return nil
    }

    private func lineNumber(containing characterIndex: Int) -> Int {
        var low = 0
        var high = lineStarts.count - 1
        var result = 1

        while low <= high {
            let mid = (low + high) / 2
            if lineStarts[mid] <= characterIndex {
                result = mid + 1
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }
}
