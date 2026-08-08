//
//  MarkdownParser.swift
//  DeliveryBar
//
//  备忘正文的块级 Markdown 解析。只做块结构（标题 / 列表 / 代码块 / 引用 / 分割线 / 图片），
//  行内样式（**粗体**、`代码`、[链接]）交给 AttributedString(markdown:) 处理，
//  两边加起来刚好够记流程和贴报错栈，也不用引三方依赖。
//

import Foundation

struct MarkdownListItem: Identifiable {
    let id: Int
    let text: String
    /// nil 表示普通列表项；非 nil 表示 `- [ ]` / `- [x]` 任务项
    let isChecked: Bool?
    /// 缩进层级，0 起，最多 2 层
    let indent: Int
}

struct MarkdownBlock: Identifiable {
    enum Kind {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case bulletList(items: [MarkdownListItem])
        case orderedList(start: Int, items: [MarkdownListItem])
        case codeBlock(language: String, code: String)
        case quote(text: String)
        case divider
        case image(alt: String, reference: String)
    }

    let id: Int
    let kind: Kind
}

enum MarkdownParser {
    private static let maxIndent = 2
    private static let fence = "```"

    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var quoteLines: [String] = []
        var listItems: [MarkdownListItem] = []
        var listIsOrdered = false
        var listStart = 1

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            append(&blocks, .paragraph(text: paragraphLines.joined(separator: "\n")))
            paragraphLines.removeAll()
        }

        func flushQuote() {
            guard !quoteLines.isEmpty else { return }
            append(&blocks, .quote(text: quoteLines.joined(separator: "\n")))
            quoteLines.removeAll()
        }

        func flushList() {
            guard !listItems.isEmpty else { return }
            append(
                &blocks,
                listIsOrdered
                    ? .orderedList(start: listStart, items: listItems)
                    : .bulletList(items: listItems)
            )
            listItems.removeAll()
        }

        func flushAll() {
            flushParagraph()
            flushQuote()
            flushList()
        }

        var lines = source.components(separatedBy: "\n")[...]

        while let line = lines.first {
            lines = lines.dropFirst()
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 代码块优先：围栏内的一切都按原样保留，不再解析
            if trimmed.hasPrefix(fence) {
                flushAll()
                let language = String(trimmed.dropFirst(fence.count)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                while let next = lines.first {
                    lines = lines.dropFirst()
                    if next.trimmingCharacters(in: .whitespaces).hasPrefix(fence) { break }
                    code.append(next)
                }
                append(&blocks, .codeBlock(language: language, code: code.joined(separator: "\n")))
                continue
            }

            if trimmed.isEmpty {
                flushAll()
                continue
            }

            if isDivider(trimmed) {
                flushAll()
                append(&blocks, .divider)
                continue
            }

            if let heading = headingComponents(trimmed) {
                flushAll()
                append(&blocks, .heading(level: heading.level, text: heading.text))
                continue
            }

            if let image = imageComponents(trimmed) {
                flushAll()
                append(&blocks, .image(alt: image.alt, reference: image.reference))
                continue
            }

            if let quote = quoteContent(trimmed) {
                flushParagraph()
                flushList()
                quoteLines.append(quote)
                continue
            }

            if let bullet = bulletComponents(line) {
                flushParagraph()
                flushQuote()
                if listIsOrdered { flushList() }
                listIsOrdered = false
                listItems.append(
                    MarkdownListItem(
                        id: listItems.count,
                        text: bullet.text,
                        isChecked: bullet.isChecked,
                        indent: bullet.indent
                    )
                )
                continue
            }

            if let ordered = orderedComponents(line) {
                flushParagraph()
                flushQuote()
                if !listIsOrdered { flushList() }
                if listItems.isEmpty {
                    listIsOrdered = true
                    listStart = ordered.number
                }
                listItems.append(
                    MarkdownListItem(
                        id: listItems.count,
                        text: ordered.text,
                        isChecked: nil,
                        indent: ordered.indent
                    )
                )
                continue
            }

            flushQuote()
            flushList()
            paragraphLines.append(line)
        }

        flushAll()
        return blocks
    }

    private static func append(_ blocks: inout [MarkdownBlock], _ kind: MarkdownBlock.Kind) {
        blocks.append(MarkdownBlock(id: blocks.count, kind: kind))
    }

    /// `---` / `***` / `___`，三个以上且只有这一种字符
    private static func isDivider(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        for marker in ["-", "*", "_"] where trimmed.allSatisfy({ String($0) == marker }) {
            return true
        }
        return false
    }

    private static func headingComponents(_ trimmed: String) -> (level: Int, text: String)? {
        let hashes = trimmed.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }

        let rest = trimmed.dropFirst(hashes.count)
        // `#tag` 这种不是标题，井号后必须是空格或直接结束
        guard rest.isEmpty || rest.first == " " else { return nil }
        return (hashes.count, rest.trimmingCharacters(in: .whitespaces))
    }

    /// 独占一行的 `![alt](ref)` 才当图片块，混在句子里的仍走行内解析
    private static func imageComponents(_ trimmed: String) -> (alt: String, reference: String)? {
        guard trimmed.hasPrefix("!["), trimmed.hasSuffix(")"), trimmed.count > 5 else { return nil }

        let inner = trimmed.dropFirst(2).dropLast()
        guard let separator = inner.range(of: "](") else { return nil }

        let reference = String(inner[separator.upperBound...])
        guard !reference.isEmpty else { return nil }
        return (String(inner[..<separator.lowerBound]), reference)
    }

    private static func quoteContent(_ trimmed: String) -> String? {
        guard trimmed.hasPrefix(">") else { return nil }
        return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static func bulletComponents(_ line: String) -> (text: String, isChecked: Bool?, indent: Int)? {
        let indent = indentLevel(of: line)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.first, "-*+".contains(marker) else { return nil }

        let rest = trimmed.dropFirst()
        guard rest.first == " " else { return nil }

        var text = String(rest).trimmingCharacters(in: .whitespaces)

        // `- [ ] 待办` / `- [x] 已完成`
        var isChecked: Bool?
        if text.hasPrefix("[ ] ") || text == "[ ]" {
            isChecked = false
            text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else if text.lowercased().hasPrefix("[x] ") || text.lowercased() == "[x]" {
            isChecked = true
            text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }

        return (text, isChecked, indent)
    }

    private static func orderedComponents(_ line: String) -> (number: Int, text: String, indent: Int)? {
        let indent = indentLevel(of: line)
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let digits = trimmed.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3, let number = Int(digits) else { return nil }

        let rest = trimmed.dropFirst(digits.count)
        guard let separator = rest.first, separator == "." || separator == ")" else { return nil }

        let body = rest.dropFirst()
        // `1.` 单独一行也算（模板骨架就是这样），后面有内容时必须隔一个空格
        guard body.isEmpty || body.first == " " else { return nil }
        return (number, body.trimmingCharacters(in: .whitespaces), indent)
    }

    private static func indentLevel(of line: String) -> Int {
        var spaces = 0
        for character in line {
            if character == " " {
                spaces += 1
            } else if character == "\t" {
                spaces += 4
            } else {
                break
            }
        }
        return min(spaces / 2, maxIndent)
    }
}
