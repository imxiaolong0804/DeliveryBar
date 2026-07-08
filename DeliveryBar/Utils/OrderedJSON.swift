//
//  OrderedJSON.swift
//  DeliveryBar
//
//  保序 JSON 解析与渲染，供格式化与比对共用。
//

import Foundation

enum JSONFormatterEngine {
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

enum OrderedJSONValue {
    case object([(key: String, value: OrderedJSONValue)])
    case array([OrderedJSONValue])
    case string(String)
    case number(String)
    case bool(Bool)
    case null
}

struct OrderedJSONParseError: LocalizedError {
    let message: String
    let line: Int
    let column: Int

    var errorDescription: String? {
        "第 \(line) 行，第 \(column) 列：\(message)"
    }
}

final class OrderedJSONParser {
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

enum OrderedJSONRenderer {
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

enum JSONFormatterError: LocalizedError {
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            "无法按 UTF-8 读取或输出这段 JSON"
        }
    }
}
