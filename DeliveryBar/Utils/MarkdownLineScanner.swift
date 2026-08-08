//
//  MarkdownLineScanner.swift
//  DeliveryBar
//
//  备忘编辑器着色用的行级扫描器。
//

import Foundation

enum MarkdownLineKind {
    /// marker 是 `#` `-` `>` 这些语法符号本身（含紧跟的一个空格），要淡化但不隐藏
    case heading(level: Int, marker: NSRange)
    case bullet(marker: NSRange)
    case ordered(marker: NSRange)
    case quote(marker: NSRange)
    /// ``` 围栏行
    case codeFence
    /// 围栏之间的内容
    case codeBody
    case divider
    case paragraph
}

struct MarkdownLine {
    /// 不含行尾换行符
    let range: NSRange
    let kind: MarkdownLineKind
}

enum MarkdownSpanKind {
    case code
    case bold
    case italic
    case strikethrough
}

struct MarkdownSpan {
    /// 含两侧标记符号的完整范围
    let range: NSRange
    /// 单侧标记符号长度：`code` 是 1，**bold** / ~~del~~ 是 2
    let markerLength: Int
    let kind: MarkdownSpanKind
}

/// 和 MarkdownParser 是两套东西：那个产出块结构供 SwiftUI 渲染预览，
/// 这个只回答「哪一段字符是什么语法角色」，因为给 NSTextStorage 上样式要的是位置。
enum MarkdownLineScanner {
    /// 超过这个长度不着色。备忘正文正常在几十 KB 以内，粘进来一整份日志就别卡着输入了。
    static let lengthLimit = 400_000

    private enum Byte {
        static let tab: unichar = 0x09
        static let newline: unichar = 0x0A
        static let space: unichar = 0x20
    }

    // MARK: Lines

    static func lines(in source: NSString) -> [MarkdownLine] {
        let length = source.length
        guard length <= lengthLimit else { return [] }

        var result: [MarkdownLine] = []
        var insideFence = false
        var lineStart = 0

        while true {
            var lineEnd = lineStart
            while lineEnd < length, source.character(at: lineEnd) != Byte.newline {
                lineEnd += 1
            }

            let range = NSRange(location: lineStart, length: lineEnd - lineStart)
            result.append(MarkdownLine(range: range, kind: kind(of: range, in: source, insideFence: &insideFence)))

            guard lineEnd < length else { break }
            lineStart = lineEnd + 1
        }

        return result
    }

    private static func kind(of range: NSRange, in source: NSString, insideFence: inout Bool) -> MarkdownLineKind {
        let text = source.substring(with: range)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("```") {
            insideFence.toggle()
            return .codeFence
        }
        if insideFence {
            return .codeBody
        }
        if isDivider(trimmed) {
            return .divider
        }

        // marker 全是 ASCII，用 UTF-16 偏移量算长度是准的；正文有中文也不影响
        let indent = leadingWhitespaceLength(of: range, in: source)
        let markerStart = range.location + indent

        if let level = headingLevel(trimmed) {
            let hasSpace = trimmed.count > level
            return .heading(level: level, marker: NSRange(location: markerStart, length: level + (hasSpace ? 1 : 0)))
        }
        if trimmed.hasPrefix(">") {
            let hasSpace = trimmed.dropFirst().first == " "
            return .quote(marker: NSRange(location: markerStart, length: hasSpace ? 2 : 1))
        }
        if let length = bulletMarkerLength(trimmed) {
            return .bullet(marker: NSRange(location: markerStart, length: length))
        }
        if let length = orderedMarkerLength(trimmed) {
            return .ordered(marker: NSRange(location: markerStart, length: length))
        }

        return .paragraph
    }

    /// `---` / `***` / `___`，三个以上且只有这一种字符
    private static func isDivider(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        for marker in ["-", "*", "_"] where trimmed.allSatisfy({ String($0) == marker }) {
            return true
        }
        return false
    }

    private static func headingLevel(_ trimmed: String) -> Int? {
        let hashes = trimmed.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }

        let rest = trimmed.dropFirst(hashes.count)
        // `#tag` 不是标题
        guard rest.isEmpty || rest.first == " " else { return nil }
        return hashes.count
    }

    /// 返回 `- ` / `- [x] ` 这类前缀的长度
    private static func bulletMarkerLength(_ trimmed: String) -> Int? {
        guard let marker = trimmed.first, "-*+".contains(marker) else { return nil }

        let rest = trimmed.dropFirst()
        guard rest.first == " " else { return nil }

        let body = rest.dropFirst()
        if body.hasPrefix("[ ] ") || body.hasPrefix("[x] ") || body.hasPrefix("[X] ") {
            return 6
        }
        if body == "[ ]" || body.lowercased() == "[x]" {
            return 5
        }
        return 2
    }

    /// 返回 `1. ` 这类前缀的长度
    private static func orderedMarkerLength(_ trimmed: String) -> Int? {
        let digits = trimmed.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3 else { return nil }

        let rest = trimmed.dropFirst(digits.count)
        guard let separator = rest.first, separator == "." || separator == ")" else { return nil }

        let body = rest.dropFirst()
        guard body.isEmpty || body.first == " " else { return nil }
        return digits.count + 1 + (body.isEmpty ? 0 : 1)
    }

    private static func leadingWhitespaceLength(of range: NSRange, in source: NSString) -> Int {
        var length = 0

        while length < range.length {
            let character = source.character(at: range.location + length)
            guard character == Byte.space || character == Byte.tab else { break }
            length += 1
        }

        return length
    }

    // MARK: Inline spans

    /// 顺序即优先级：code 先占位，它内部的 `*` `~` 一律按字面量处理
    private static let patterns: [(kind: MarkdownSpanKind, markerLength: Int, regex: NSRegularExpression)] = {
        // 星号紧贴内容才算强调：`3 * 4 天`、`ls *.log` 里的星号两边有空格，不该被标成斜体。
        // 没有再加 \w 边界（标准 Markdown 那套 intra-word 限制），否则中文写 `*重点*后面`
        // 会因为紧跟汉字而失效——中文本来就不靠空格分词。
        let definitions: [(MarkdownSpanKind, Int, String)] = [
            (.code, 1, "`[^`\\n]+`"),
            (.bold, 2, "\\*\\*(?=[^\\s*])[^*\\n]*(?<=[^\\s*])\\*\\*"),
            (.strikethrough, 2, "~~(?=[^\\s~])[^~\\n]*(?<=[^\\s~])~~"),
            (.italic, 1, "(?<!\\*)\\*(?=[^\\s*])[^*\\n]*(?<=[^\\s*])\\*(?!\\*)")
        ]

        return definitions.compactMap { kind, markerLength, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (kind, markerLength, regex)
        }
    }()

    static func spans(in source: String, within lineRange: NSRange) -> [MarkdownSpan] {
        var spans: [MarkdownSpan] = []
        var occupied: [NSRange] = []

        for pattern in patterns {
            pattern.regex.enumerateMatches(in: source, range: lineRange) { match, _, _ in
                guard let range = match?.range else { return }
                guard !occupied.contains(where: { NSIntersectionRange($0, range).length > 0 }) else { return }

                occupied.append(range)
                spans.append(MarkdownSpan(range: range, markerLength: pattern.markerLength, kind: pattern.kind))
            }
        }

        return spans
    }
}
