//
//  MenuBarLabelView.swift
//  DeliveryBar
//

import SwiftData
import SwiftUI

struct MenuBarLabelView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("remindersEnabled") private var remindersEnabled = true
    @Query private var requirements: [Requirement]
    @Query(sort: \TemporaryTask.updatedAt, order: .reverse) private var temporaryTasks: [TemporaryTask]

    private var attentionCount: Int {
        requirements.filter {
            ReminderService.attentionReason(for: $0, remindersEnabled: remindersEnabled) != nil
        }.count
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checklist")

            if attentionCount > 0 {
                Text("\(attentionCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
        }
        .accessibilityLabel(accessibilityText)
        .onAppear {
            migrateLegacyUndeliveredRequirements()
            cleanupExpiredTemporaryTasks()
        }
    }

    private var accessibilityText: String {
        if attentionCount > 0 {
            return "\(DeliveryBarTheme.appName), \(attentionCount) 个需求需要关注"
        }
        return DeliveryBarTheme.appName
    }

    private func cleanupExpiredTemporaryTasks() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cutoffDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        temporaryTasks
            .filter { calendar.startOfDay(for: $0.taskDate) < cutoffDate }
            .forEach { modelContext.delete($0) }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save model context: \(error)")
        }
    }

    private func migrateLegacyUndeliveredRequirements() {
        let legacyRequirements = requirements.filter { $0.status == .developedNotDelivered }
        guard !legacyRequirements.isEmpty else { return }

        legacyRequirements.forEach {
            $0.statusRaw = RequirementStatus.waitingAcceptance.rawValue
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save model context: \(error)")
        }
    }
}
