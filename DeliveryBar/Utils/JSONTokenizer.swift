//
//  JSONTokenizer.swift
//  DeliveryBar
//
//  JSON 着色用的扫描器。
//

import Foundation

enum JSONTokenKind {
    /// 对象里冒号左边的字符串
    case key
    case string
    case number
    case boolean
    /// 和 boolean 分开是因为 null 要单独走斜体
    case null
    /// { } [ ] , :
    case punctuation
}

struct JSONToken {
    let range: NSRange
    let kind: JSONTokenKind
}

/// 边输入边着色，扫到的多半是半截 JSON，所以这里只认形状不做校验，任何输入都要能扫完。
///
/// 没有复用 OrderedJSONParser：那个产出的是语法树，token 位置在解析过程中就丢了，
/// 而且遇到非法 JSON 直接抛错——输入到一半整段就会失去颜色。
enum JSONTokenizer {
    /// 超过这个长度不着色。全量扫一遍 1MB 大约十几毫秒，再大就会拖住输入。
    static let lengthLimit = 1_000_000

    private enum Byte {
        static let tab: unichar = 0x09
        static let newline: unichar = 0x0A
        static let carriageReturn: unichar = 0x0D
        static let space: unichar = 0x20
        static let quote: unichar = 0x22
        static let plus: unichar = 0x2B
        static let comma: unichar = 0x2C
        static let minus: unichar = 0x2D
        static let dot: unichar = 0x2E
        static let zero: unichar = 0x30
        static let nine: unichar = 0x39
        static let colon: unichar = 0x3A
        static let upperA: unichar = 0x41
        static let upperE: unichar = 0x45
        static let upperZ: unichar = 0x5A
        static let openBracket: unichar = 0x5B
        static let backslash: unichar = 0x5C
        static let closeBracket: unichar = 0x5D
        static let lowerA: unichar = 0x61
        static let lowerE: unichar = 0x65
        static let lowerZ: unichar = 0x7A
        static let openBrace: unichar = 0x7B
        static let closeBrace: unichar = 0x7D
    }

    static func tokens(in source: NSString) -> [JSONToken] {
        let length = source.length
        guard length <= lengthLimit else { return [] }

        var tokens: [JSONToken] = []
        var index = 0

        while index < length {
            let character = source.character(at: index)

            switch character {
            case Byte.quote:
                let start = index
                index = endOfString(in: source, from: index, length: length)
                let kind: JSONTokenKind = isFollowedByColon(in: source, from: index, length: length) ? .key : .string
                tokens.append(JSONToken(range: NSRange(location: start, length: index - start), kind: kind))

            case Byte.openBrace, Byte.closeBrace, Byte.openBracket, Byte.closeBracket, Byte.comma, Byte.colon:
                tokens.append(JSONToken(range: NSRange(location: index, length: 1), kind: .punctuation))
                index += 1

            case Byte.minus, Byte.zero...Byte.nine:
                let start = index
                index += 1
                while index < length, isNumberBody(source.character(at: index)) {
                    index += 1
                }
                tokens.append(JSONToken(range: NSRange(location: start, length: index - start), kind: .number))

            case let letter where isLetter(letter):
                let start = index
                while index < length, isLetter(source.character(at: index)) {
                    index += 1
                }
                let range = NSRange(location: start, length: index - start)
                switch source.substring(with: range) {
                case "null":
                    tokens.append(JSONToken(range: range, kind: .null))
                case "true", "false":
                    tokens.append(JSONToken(range: range, kind: .boolean))
                default:
                    break
                }

            default:
                index += 1
            }
        }

        return tokens
    }

    /// 返回字符串 token 的结束位置（闭合引号之后）。
    /// 碰到换行就地截断——少打一个引号不该把后面整篇都染成字符串色。
    private static func endOfString(in source: NSString, from start: Int, length: Int) -> Int {
        var index = start + 1

        while index < length {
            switch source.character(at: index) {
            case Byte.backslash:
                index += 2
            case Byte.quote:
                return index + 1
            case Byte.newline, Byte.carriageReturn:
                return index
            default:
                index += 1
            }
        }

        return length
    }

    private static func isFollowedByColon(in source: NSString, from start: Int, length: Int) -> Bool {
        var index = start

        while index < length {
            let character = source.character(at: index)
            guard !isWhitespace(character) else {
                index += 1
                continue
            }
            return character == Byte.colon
        }

        return false
    }

    private static func isWhitespace(_ character: unichar) -> Bool {
        character == Byte.space || character == Byte.newline
            || character == Byte.carriageReturn || character == Byte.tab
    }

    private static func isNumberBody(_ character: unichar) -> Bool {
        (Byte.zero...Byte.nine).contains(character)
            || character == Byte.dot
            || character == Byte.lowerE || character == Byte.upperE
            || character == Byte.plus || character == Byte.minus
    }

    private static func isLetter(_ character: unichar) -> Bool {
        (Byte.lowerA...Byte.lowerZ).contains(character) || (Byte.upperA...Byte.upperZ).contains(character)
    }
}
