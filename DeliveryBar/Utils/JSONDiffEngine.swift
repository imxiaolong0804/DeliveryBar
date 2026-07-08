//
//  JSONDiffEngine.swift
//  DeliveryBar
//
//  结构化比对两段 JSON：对象按 key 匹配（忽略顺序），数组按下标匹配。
//

import Foundation

enum JSONDiffKind {
    case added      // 仅右侧存在
    case removed    // 仅左侧存在
    case changed    // 两侧值不同

    var title: String {
        switch self {
        case .added:
            "新增"
        case .removed:
            "缺失"
        case .changed:
            "不同"
        }
    }
}

struct JSONDiffEntry: Identifiable {
    let id = UUID()
    let path: String
    let kind: JSONDiffKind
    let leftText: String?
    let rightText: String?
}

enum JSONDiffEngine {
    private static let displayTextLimit = 200

    static func diff(left: OrderedJSONValue, right: OrderedJSONValue) -> [JSONDiffEntry] {
        var entries: [JSONDiffEntry] = []
        compare(left: left, right: right, path: "$", into: &entries)
        return entries
    }

    private static func compare(
        left: OrderedJSONValue,
        right: OrderedJSONValue,
        path: String,
        into entries: inout [JSONDiffEntry]
    ) {
        switch (left, right) {
        case (.object(let leftEntries), .object(let rightEntries)):
            compareObjects(left: leftEntries, right: rightEntries, path: path, into: &entries)
        case (.array(let leftValues), .array(let rightValues)):
            compareArrays(left: leftValues, right: rightValues, path: path, into: &entries)
        default:
            // 标量或类型不一致：按紧凑渲染文本判等（number 按原文比较）
            let leftRendered = OrderedJSONRenderer.render(left, prettyPrinted: false)
            let rightRendered = OrderedJSONRenderer.render(right, prettyPrinted: false)
            if leftRendered != rightRendered {
                entries.append(JSONDiffEntry(
                    path: path,
                    kind: .changed,
                    leftText: displayText(leftRendered),
                    rightText: displayText(rightRendered)
                ))
            }
        }
    }

    private static func compareObjects(
        left: [(key: String, value: OrderedJSONValue)],
        right: [(key: String, value: OrderedJSONValue)],
        path: String,
        into entries: inout [JSONDiffEntry]
    ) {
        let rightByKey = Dictionary(right.map { ($0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
        let leftKeys = Set(left.map(\.key))

        for (key, leftValue) in left {
            let childPath = path + pathComponent(forKey: key)
            if let rightValue = rightByKey[key] {
                compare(left: leftValue, right: rightValue, path: childPath, into: &entries)
            } else {
                entries.append(JSONDiffEntry(
                    path: childPath,
                    kind: .removed,
                    leftText: displayText(for: leftValue),
                    rightText: nil
                ))
            }
        }

        for (key, rightValue) in right where !leftKeys.contains(key) {
            entries.append(JSONDiffEntry(
                path: path + pathComponent(forKey: key),
                kind: .added,
                leftText: nil,
                rightText: displayText(for: rightValue)
            ))
        }
    }

    private static func compareArrays(
        left: [OrderedJSONValue],
        right: [OrderedJSONValue],
        path: String,
        into entries: inout [JSONDiffEntry]
    ) {
        let commonCount = min(left.count, right.count)

        for index in 0..<commonCount {
            compare(left: left[index], right: right[index], path: "\(path)[\(index)]", into: &entries)
        }

        for index in commonCount..<left.count {
            entries.append(JSONDiffEntry(
                path: "\(path)[\(index)]",
                kind: .removed,
                leftText: displayText(for: left[index]),
                rightText: nil
            ))
        }

        for index in commonCount..<right.count {
            entries.append(JSONDiffEntry(
                path: "\(path)[\(index)]",
                kind: .added,
                leftText: nil,
                rightText: displayText(for: right[index])
            ))
        }
    }

    private static func pathComponent(forKey key: String) -> String {
        let isPlainIdentifier = !key.isEmpty
            && key.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
            && !(key.first?.isNumber ?? true)
        return isPlainIdentifier ? ".\(key)" : "[\"\(key)\"]"
    }

    private static func displayText(for value: OrderedJSONValue) -> String {
        displayText(OrderedJSONRenderer.render(value, prettyPrinted: false))
    }

    private static func displayText(_ rendered: String) -> String {
        guard rendered.count > displayTextLimit else { return rendered }
        return rendered.prefix(displayTextLimit) + "…"
    }
}
