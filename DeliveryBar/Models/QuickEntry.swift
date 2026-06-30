//
//  QuickEntry.swift
//  DeliveryBar
//

import Foundation
import SwiftData

enum QuickEntryType: String, Codable, CaseIterable, Identifiable {
    case link
    case script
    case snippet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .link:
            "链接"
        case .script:
            "脚本"
        case .snippet:
            "文本"
        }
    }

    var systemImage: String {
        switch self {
        case .link:
            "link"
        case .script:
            "terminal"
        case .snippet:
            "doc.text"
        }
    }

    var actionTitle: String {
        switch self {
        case .link:
            "打开链接"
        case .script:
            "复制脚本"
        case .snippet:
            "复制文本"
        }
    }

    var actionImage: String {
        switch self {
        case .link:
            "safari"
        case .script, .snippet:
            "doc.on.doc"
        }
    }
}

@Model
final class QuickEntry {
    @Attribute(.unique) var id: UUID
    var key: String
    var value: String
    var typeRaw: String
    var note: String
    var tag: String
    var usageCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        key: String,
        value: String,
        type: QuickEntryType = .link,
        note: String = "",
        tag: String = "",
        usageCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.typeRaw = type.rawValue
        self.note = note
        self.tag = tag
        self.usageCount = usageCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: QuickEntryType {
        get { QuickEntryType(rawValue: typeRaw) ?? .link }
        set {
            typeRaw = newValue.rawValue
            touch()
        }
    }

    func markUsed() {
        usageCount += 1
        touch()
    }

    func touch() {
        updatedAt = Date()
    }
}
