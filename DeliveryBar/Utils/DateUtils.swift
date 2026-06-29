//
//  DateUtils.swift
//  DeliveryBar
//

import Foundation

enum DateUtils {
    static func dayCount(from startDate: Date, to endDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    static func relativeUpdateText(for date: Date, now: Date = Date()) -> String {
        let days = dayCount(from: date, to: now)
        switch days {
        case 0:
            return "今天更新"
        case 1:
            return "昨天更新"
        default:
            return "\(days) 天前更新"
        }
    }

    static func dueText(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        switch days {
        case let value where value < 0:
            return "已逾期 \(abs(value)) 天"
        case 0:
            return "今天到期"
        case 1:
            return "明天到期"
        default:
            return "\(days) 天后到期"
        }
    }
}
