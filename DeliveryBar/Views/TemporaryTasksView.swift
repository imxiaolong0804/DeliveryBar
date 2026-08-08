//
//  TemporaryTasksView.swift
//  DeliveryBar
//

import SwiftData
import SwiftUI

struct TemporaryTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TemporaryTask.updatedAt, order: .reverse) private var temporaryTasks: [TemporaryTask]

    let listHeight: CGFloat
    let weekListHeight: CGFloat
    @Binding var selectedDate: Date
    @Binding var viewMode: LogViewMode
    @Binding var noteExpanded: Bool

    @State private var title = ""
    @State private var note = ""
    @State private var validationMessage: String?
    @State private var didCopyReport = false

    private var calendar: Calendar { .current }

    // MARK: - Day mode

    private var selectedTasks: [TemporaryTask] {
        temporaryTasks
            .filter { task in
                task.category == .log && calendar.isDate(task.taskDate, inSameDayAs: selectedDate)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Week mode

    private var groupedLogs: [(date: Date, logs: [TemporaryTask])] {
        let today = calendar.startOfDay(for: Date())
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }

        let weekLogs = temporaryTasks.filter {
            $0.category == .log && $0.taskDate >= sevenDaysAgo && $0.taskDate <= today
        }

        let grouped = Dictionary(grouping: weekLogs) { calendar.startOfDay(for: $0.taskDate) }
        return grouped.keys
            .sorted(by: >)
            .map { date in
                (date: date, logs: grouped[date]!.sorted { $0.updatedAt > $1.updatedAt })
            }
    }

    private var weekSummaryText: String {
        let total = groupedLogs.reduce(0) { $0 + $1.logs.count }
        if total == 0 { return "近7天暂无日志" }
        return "近7天 \(total) 条 · \(groupedLogs.count) 天"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewMode == .day {
                dayToolbar
                Divider()
                addForm
                Divider()
                dayLogList
            } else {
                weekToolbar
                Divider()
                weekLogList
            }
        }
        .onAppear {
            ensureSelectedDateInRange()
        }
    }

    // MARK: - Toolbars

    private var dayToolbar: some View {
        HStack(spacing: 4) {
            DayStripSelector(selectedDate: $selectedDate)

            Spacer(minLength: 8)

            modeToggle
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var weekToolbar: some View {
        HStack(spacing: 8) {
            Text(weekSummaryText)
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            Spacer()

            Button {
                copyWeeklyReport()
            } label: {
                Label(
                    didCopyReport ? "已复制" : "复制周报",
                    systemImage: didCopyReport ? "checkmark" : "doc.on.doc"
                )
                .font(DeliveryBarTheme.Typography.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(didCopyReport ? DeliveryBarTheme.success : DeliveryBarTheme.accent)
            .disabled(groupedLogs.isEmpty)

            modeToggle
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var modeToggle: some View {
        Picker("", selection: $viewMode) {
            Text("日").tag(LogViewMode.day)
            Text("周").tag(LogViewMode.week)
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: 72)
        .labelsHidden()
    }

    // MARK: - Add Form

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(DeliveryBarTheme.accent)

                TextField("记录当天的事情，回车提交", text: $title)
                    .textFieldStyle(.plain)
                    .font(DeliveryBarTheme.Typography.caption)
                    .onSubmit(addTask)

                Button {
                    noteExpanded.toggle()
                } label: {
                    Image(systemName: "text.alignleft")
                        .font(DeliveryBarTheme.Typography.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(noteExpanded ? DeliveryBarTheme.accent : DeliveryBarTheme.softText)
                .help("添加备注")
            }

            if noteExpanded {
                TextField("备注，可选", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(DeliveryBarTheme.Typography.caption)
                    .lineLimit(1...3)
                    .onSubmit(addTask)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.danger)
            }
        }
        .animation(.snappy(duration: 0.16), value: noteExpanded)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Day Log List

    private var dayLogList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if selectedTasks.isEmpty {
                    emptyState(hint: "在上方记录做过的事，写日报更轻松")
                } else {
                    ForEach(selectedTasks) { task in
                        LogRow(task: task) {
                            modelContext.delete(task)
                            modelContext.saveChanges()
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: listHeight)
        .clipped()
    }

    // MARK: - Week Log List

    private var weekLogList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if groupedLogs.isEmpty {
                    emptyState(hint: "近7天还没有日志记录")
                } else {
                    ForEach(Array(groupedLogs.enumerated()), id: \.element.date) { index, group in
                        daySectionHeader(group.date, logs: group.logs, isFirst: index == 0)

                        ForEach(group.logs) { task in
                            LogRow(task: task) {
                                modelContext.delete(task)
                                modelContext.saveChanges()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: weekListHeight)
        .clipped()
    }

    private func daySectionHeader(_ date: Date, logs: [TemporaryTask], isFirst: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(DeliveryBarTheme.accent)
                .frame(width: 6, height: 6)

            Text(weekdayDateText(for: date))
                .font(DeliveryBarTheme.Typography.captionStrong)
                .foregroundStyle(DeliveryBarTheme.ink)

            Text("\(logs.count) 条")
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            VStack(spacing: 0) { Divider() }
        }
        .padding(.horizontal, 8)
        .padding(.top, isFirst ? 2 : 10)
        .padding(.bottom, 4)
    }

    private func emptyState(hint: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DeliveryBarTheme.muted)

            Text("暂无日志")
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            Text(hint)
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    private func copyWeeklyReport() {
        var report = "# 周报\n\n"

        for group in groupedLogs {
            let dateStr = group.date.formatted(.dateTime.year().month().day())
            let weekdaySymbols = calendar.shortStandaloneWeekdaySymbols
            let weekday = weekdaySymbols[calendar.component(.weekday, from: group.date) - 1]
            report += "## \(dateStr) (\(weekday))\n"
            for log in group.logs {
                report += "- \(log.title)"
                if !log.note.isEmpty {
                    report += "：\(log.note)"
                }
                report += "\n"
            }
            report += "\n"
        }

        Clipboard.copy(report.trimmingCharacters(in: .newlines))

        withAnimation(.snappy(duration: 0.16)) {
            didCopyReport = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.snappy(duration: 0.16)) {
                didCopyReport = false
            }
        }
    }

    // MARK: - Actions

    private func addTask() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            validationMessage = "内容不能为空"
            return
        }

        let task = TemporaryTask(
            title: normalizedTitle,
            category: .log,
            note: normalizedNote,
            taskDate: selectedDate
        )
        modelContext.insert(task)
        title = ""
        note = ""
        noteExpanded = false
        validationMessage = nil
        modelContext.saveChanges()
    }

    private func ensureSelectedDateInRange() {
        let startOfSelectedDate = calendar.startOfDay(for: selectedDate)
        let visibleDates = DayStripSelector.recentDates(calendar: calendar)
        if !visibleDates.contains(where: { calendar.isDate($0, inSameDayAs: startOfSelectedDate) }) {
            selectedDate = calendar.startOfDay(for: Date())
        }
    }

    private func weekdayDateText(for date: Date) -> String {
        let weekday = date.formatted(.dateTime.weekday(.wide))
        let monthDay = date.formatted(.dateTime.month(.defaultDigits).day())
        return "\(weekday) \(monthDay)"
    }
}

// MARK: - Log Row

/// 日志行：时间 + 内容的时间线样式，日/周视图共用
private struct LogRow: View {
    let task: TemporaryTask
    let onDelete: () -> Void

    var body: some View {
        CompactTaskRow(copyText: task.copyText, onDelete: onDelete) {
            Text(task.createdAt, style: .time)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(DeliveryBarTheme.softText)
                .frame(width: 40, alignment: .leading)
                .padding(.top, 2)
        } content: {
            Text(task.title)
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.ink)
                .lineLimit(3)

            if !task.note.isEmpty {
                Text(task.note)
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
                    .lineLimit(3)
            }
        }
    }
}
