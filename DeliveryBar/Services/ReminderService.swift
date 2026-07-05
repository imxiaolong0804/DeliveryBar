//
//  ReminderService.swift
//  DeliveryBar
//

import Foundation

enum ReminderService {
    static func attentionReason(
        for requirement: Requirement,
        remindersEnabled: Bool,
        now: Date = Date()
    ) -> String? {
        guard remindersEnabled, requirement.status != .archived else {
            return nil
        }

        if let mutedUntil = requirement.reminderMutedUntil, mutedUntil > now {
            return nil
        }

        if let dueDate = requirement.dueDate {
            let dueText = DateUtils.dueText(for: dueDate, now: now)
            if dueText.hasPrefix("已逾期") || dueText == "今天到期" {
                return dueText
            }
        }

        guard let thresholdDays = requirement.status.reminderThresholdDays else {
            return nil
        }

        let elapsedDays = DateUtils.dayCount(from: requirement.statusChangedAt, to: now)
        guard elapsedDays >= thresholdDays else {
            return nil
        }

        switch requirement.status {
        case .developing:
            return "\(elapsedDays) 天未推进"
        case .developedNotDelivered:
            return "\(elapsedDays) 天未交付"
        case .waitingAcceptance:
            return "\(elapsedDays) 天测试中"
        case .waitingRelease:
            return "\(elapsedDays) 天待上线"
        case .todo, .completed, .archived:
            return nil
        }
    }
}
