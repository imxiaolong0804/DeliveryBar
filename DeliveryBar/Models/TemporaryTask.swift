//
//  TemporaryTask.swift
//  DeliveryBar
//

import Foundation
import SwiftData

enum TemporaryTaskType: String, Codable, CaseIterable, Identifiable {
    case caseInvestigation
    case integration
    case issueNote
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caseInvestigation:
            "case排查"
        case .integration:
            "联调"
        case .issueNote:
            "问题记录"
        case .other:
            "其他"
        }
    }

    static let defaultTitle = TemporaryTaskType.caseInvestigation.title

    static var defaultTitles: [String] {
        allCases.map(\.title)
    }

    static func displayTitle(for rawValue: String) -> String {
        let normalizedValue = normalize(rawValue)
        guard !normalizedValue.isEmpty else {
            return defaultTitle
        }

        if let legacyType = TemporaryTaskType(rawValue: normalizedValue) {
            return legacyType.title
        }
        return rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func storageValue(for title: String) -> String {
        let normalizedTitle = normalize(title)
        guard !normalizedTitle.isEmpty else {
            return defaultTitle
        }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@Model
final class TemporaryTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var typeRaw: String
    var note: String
    var taskDate: Date
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        typeTitle: String = TemporaryTaskType.defaultTitle,
        note: String = "",
        taskDate: Date = Date(),
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.typeRaw = TemporaryTaskType.storageValue(for: typeTitle)
        self.note = note
        self.taskDate = Calendar.current.startOfDay(for: taskDate)
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var typeTitle: String {
        get { TemporaryTaskType.displayTitle(for: typeRaw) }
        set {
            typeRaw = TemporaryTaskType.storageValue(for: newValue)
            touch()
        }
    }

    func updateCompletion(_ isCompleted: Bool) {
        self.isCompleted = isCompleted
        touch()
    }

    func touch() {
        updatedAt = Date()
    }
}
