//
//  TemporaryTask.swift
//  DeliveryBar
//

import Foundation
import SwiftData

enum TemporaryCategory: String, Codable, CaseIterable, Identifiable {
    case todo
    case log

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todo:
            "待办"
        case .log:
            "日志"
        }
    }

    var systemImage: String {
        switch self {
        case .todo:
            "checkmark.circle"
        case .log:
            "doc.text"
        }
    }

    var emptyHint: String {
        switch self {
        case .todo:
            "暂无待办"
        case .log:
            "暂无日志"
        }
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
        category: TemporaryCategory = .todo,
        note: String = "",
        taskDate: Date = Date(),
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.typeRaw = category.rawValue
        self.note = note
        self.taskDate = Calendar.current.startOfDay(for: taskDate)
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: TemporaryCategory {
        get { TemporaryCategory(rawValue: typeRaw) ?? .todo }
        set {
            typeRaw = newValue.rawValue
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
