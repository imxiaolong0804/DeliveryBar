//
//  JSONFormatHistory.swift
//  DeliveryBar
//

import Foundation
import SwiftData

@Model
final class JSONFormatHistory {
    @Attribute(.unique) var id: UUID
    var rawJSON: String
    var formattedJSON: String
    var summary: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        rawJSON: String,
        formattedJSON: String,
        summary: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.rawJSON = rawJSON
        self.formattedJSON = formattedJSON
        self.summary = summary.isEmpty ? Self.makeSummary(from: formattedJSON) : summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(rawJSON: String, formattedJSON: String) {
        self.rawJSON = rawJSON
        self.formattedJSON = formattedJSON
        self.summary = Self.makeSummary(from: formattedJSON)
        self.updatedAt = Date()
    }

    static func makeSummary(from text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ")
            .joined(separator: " ")

        if collapsed.count <= 80 {
            return collapsed.isEmpty ? "空 JSON" : collapsed
        }

        return String(collapsed.prefix(80)) + "..."
    }
}
