//
//  PersonProfile.swift
//  DeliveryBar
//

import Foundation
import SwiftData

enum PersonRole: String, Codable, CaseIterable, Identifiable {
    case pm
    case qa

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pm:
            "PM"
        case .qa:
            "测试人员"
        }
    }
}

@Model
final class PersonProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var normalizedName: String
    var roleRaw: String
    var usageCount: Int
    var createdAt: Date
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        role: PersonRole,
        usageCount: Int = 1,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.normalizedName = Self.normalize(name)
        self.roleRaw = role.rawValue
        self.usageCount = usageCount
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    var role: PersonRole {
        get { PersonRole(rawValue: roleRaw) ?? .pm }
        set { roleRaw = newValue.rawValue }
    }

    func markUsed(name: String, at date: Date = Date()) {
        self.name = name
        normalizedName = Self.normalize(name)
        usageCount += 1
        lastUsedAt = date
    }

    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
