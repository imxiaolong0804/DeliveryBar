//
//  MaintenanceService.swift
//  DeliveryBar
//
//  历史状态迁移与过期临时任务清理。规则集中在这里，避免各视图各写一份且互相不一致。
//

import Foundation
import SwiftData

enum MaintenanceService {
    /// 临时任务保留窗口：今天往前共 7 天
    static let retentionDays = 6

    /// 备忘的「最近删除」保留天数。备忘本身不参与滚动清理——它就是拿来长期沉淀的，
    /// 只有用户主动删除后才进入这个倒计时。
    static let memoTrashRetentionDays = 30

    /// 启动时跑一次；面板切到待办/日志时再跑一次，覆盖长时间不退出的场景
    static func run(in context: ModelContext, now: Date = Date()) {
        migrateLegacyStatuses(in: context)
        purgeExpiredTemporaryTasks(in: context, now: now)
        purgeExpiredMemos(in: context, now: now)
        context.saveChanges()
    }

    static func cutoffDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -retentionDays, to: today) ?? today
    }

    /// `已开发，未交付` 是历史状态，统一迁移到 `测试中`
    private static func migrateLegacyStatuses(in context: ModelContext) {
        let legacyRaw = RequirementStatus.developedNotDelivered.rawValue
        let descriptor = FetchDescriptor<Requirement>(
            predicate: #Predicate { $0.statusRaw == legacyRaw }
        )

        guard let legacyRequirements = try? context.fetch(descriptor) else { return }
        legacyRequirements.forEach {
            $0.statusRaw = RequirementStatus.waitingAcceptance.rawValue
        }
    }

    /// 日志和「已完成的待办」只保留最近 7 天；未完成的待办一直留着，不随日期清理
    private static func purgeExpiredTemporaryTasks(in context: ModelContext, now: Date) {
        // taskDate 在 TemporaryTask.init 里已归一到 startOfDay，可以直接比大小
        let cutoff = cutoffDate(now: now)
        let logRaw = TemporaryCategory.log.rawValue
        let descriptor = FetchDescriptor<TemporaryTask>(
            predicate: #Predicate { task in
                task.taskDate < cutoff && (task.typeRaw == logRaw || task.isCompleted)
            }
        )

        guard let expiredTasks = try? context.fetch(descriptor) else { return }
        expiredTasks.forEach { context.delete($0) }
    }

    /// 「最近删除」里超过保留期的备忘物理删除，附件按 cascade 一起走。
    /// 备忘条数是个人量级，直接全量取回在 Swift 侧筛，比跟 #Predicate 的可选日期较劲省事。
    private static func purgeExpiredMemos(in context: ModelContext, now: Date) {
        guard let memos = try? context.fetch(FetchDescriptor<Memo>()) else { return }

        let calendar = Calendar.current
        for memo in memos {
            guard let deletedAt = memo.deletedAt else { continue }
            let elapsed = DateUtils.dayCount(from: deletedAt, to: now, calendar: calendar)
            if elapsed >= memoTrashRetentionDays {
                context.delete(memo)
            }
        }
    }
}
