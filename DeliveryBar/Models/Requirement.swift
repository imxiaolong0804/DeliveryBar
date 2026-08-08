//
//  Requirement.swift
//  DeliveryBar
//

import Foundation
import SwiftData

enum RequirementStatus: String, Codable, CaseIterable, Identifiable {
    case todo
    case developing
    case developedNotDelivered
    case waitingAcceptance
    case waitingRelease
    case completed
    case archived

    var id: String { rawValue }

    static let mainList: [RequirementStatus] = [
        .todo,
        .developing,
        .waitingAcceptance,
        .waitingRelease,
        .completed
    ]

    static let editableList: [RequirementStatus] = [
        .todo,
        .developing,
        .waitingAcceptance,
        .waitingRelease,
        .completed,
        .archived
    ]

    var title: String {
        switch self {
        case .todo:
            "待开发"
        case .developing:
            "正在开发"
        case .developedNotDelivered:
            "已开发，未交付"
        case .waitingAcceptance:
            "测试中"
        case .waitingRelease:
            "待上线"
        case .completed:
            "已完成"
        case .archived:
            "Archive"
        }
    }

    var nextStatus: RequirementStatus? {
        switch self {
        case .todo:
            .developing
        case .developing:
            .waitingAcceptance
        case .developedNotDelivered:
            .waitingAcceptance
        case .waitingAcceptance:
            .waitingRelease
        case .waitingRelease:
            .completed
        case .completed:
            .archived
        case .archived:
            nil
        }
    }

    var nextActionTitle: String? {
        switch self {
        case .todo:
            "开始开发"
        case .developing:
            "提测"
        case .developedNotDelivered:
            "进入测试"
        case .waitingAcceptance:
            "测试通过"
        case .waitingRelease:
            "上线完成"
        case .completed:
            "归档"
        case .archived:
            nil
        }
    }

    var reminderThresholdDays: Int? {
        switch self {
        case .developedNotDelivered:
            3
        case .developing:
            7
        case .waitingAcceptance:
            5
        case .waitingRelease:
            5
        case .todo, .completed, .archived:
            nil
        }
    }
}

enum RequirementPriority: Int, Codable, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low:
            "低"
        case .medium:
            "中"
        case .high:
            "高"
        }
    }
}

@Model
final class Requirement {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String
    var note: String
    var link: String
    var statusRaw: String
    var priorityRaw: Int
    var owner: String
    var tester: String?
    var createdAt: Date
    var updatedAt: Date
    var statusChangedAt: Date
    var dueDate: Date?
    var completedAt: Date?
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        note: String = "",
        link: String = "",
        status: RequirementStatus = .todo,
        priority: RequirementPriority = .medium,
        owner: String = "",
        tester: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        statusChangedAt: Date = Date(),
        dueDate: Date? = nil,
        completedAt: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.note = note
        self.link = link
        self.statusRaw = status.rawValue
        self.priorityRaw = priority.rawValue
        self.owner = owner
        self.tester = tester
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.statusChangedAt = statusChangedAt
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.archivedAt = archivedAt
    }

    var status: RequirementStatus {
        get { RequirementStatus(rawValue: statusRaw) ?? .todo }
        set {
            guard status != newValue else { return }
            statusRaw = newValue.rawValue
            statusChangedAt = Date()
            updatedAt = Date()

            if newValue == .completed {
                completedAt = Date()
            }
            if newValue == .archived {
                archivedAt = Date()
            } else if archivedAt != nil {
                archivedAt = nil
            }
        }
    }

    var priority: RequirementPriority {
        get { RequirementPriority(rawValue: priorityRaw) ?? .medium }
        set {
            guard priority != newValue else { return }
            priorityRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var isArchived: Bool {
        status == .archived
    }

    /// 列表搜索：query 需为已 lowercased 的非空串
    func matches(_ query: String) -> Bool {
        [title, detail, note, link, owner, tester ?? ""].contains {
            $0.lowercased().contains(query)
        }
    }

    func updateStatus(_ newStatus: RequirementStatus) {
        status = newStatus
    }

    func touch() {
        updatedAt = Date()
    }
}
