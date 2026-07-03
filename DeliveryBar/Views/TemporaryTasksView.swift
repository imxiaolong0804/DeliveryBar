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
    @Binding var selectedDate: Date

    @State private var title = ""
    @State private var note = ""
    @State private var category: TemporaryCategory = .log
    @State private var validationMessage: String?

    private var calendar: Calendar { .current }

    private var hasDraftInput: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var visibleDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private var selectedTasks: [TemporaryTask] {
        temporaryTasks
            .filter { task in
                if calendar.isDate(task.taskDate, inSameDayAs: selectedDate) {
                    return true
                }
                if task.category == .todo && !task.isCompleted
                    && calendar.startOfDay(for: task.taskDate) < calendar.startOfDay(for: selectedDate) {
                    return true
                }
                return false
            }
    }

    private var todoTasks: [TemporaryTask] {
        selectedTasks
            .filter { $0.category == .todo }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var logTasks: [TemporaryTask] {
        selectedTasks
            .filter { $0.category == .log }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var summaryText: String {
        if selectedTasks.isEmpty {
            return "当天没有记录"
        }
        let unfinishedCount = todoTasks.filter { !$0.isCompleted }.count
        let parts: [String] = []
        var result = ""
        if !todoTasks.isEmpty {
            if unfinishedCount > 0 {
                result = "\(unfinishedCount) 个待办"
            } else {
                result = "\(todoTasks.count) 个待办已完成"
            }
        }
        if !logTasks.isEmpty {
            if !result.isEmpty { result += "，" }
            result += "\(logTasks.count) 条日志"
        }
        return result.isEmpty ? "当天没有记录" : result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateSelector

            Divider()

            addForm
                .padding(10)

            Divider()

            taskList
        }
        .onAppear {
            ensureSelectedDateInRange()
            resetCategoryToLogIfPossible()
            cleanupExpiredTasks()
        }
    }

    private var dateSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("临时事项")
                        .font(.headline)

                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(DeliveryBarTheme.softText)
                }

                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(visibleDates, id: \.self) { date in
                    Button {
                        selectedDate = date
                    } label: {
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        VStack(spacing: 2) {
                            Text(dayTitle(for: date))
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text(monthDayText(for: date))
                                .font(.caption2)
                                .foregroundStyle(isSelected ? DeliveryBarTheme.inkSoft : DeliveryBarTheme.softText)
                        }
                        .foregroundStyle(DeliveryBarTheme.pillForeground(isSelected: isSelected))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(DeliveryBarTheme.pillBackground(isSelected: isSelected), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(DeliveryBarTheme.pillStroke(isSelected: isSelected))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                CategoryPicker(selection: $category)

                TextField(
                    category == .todo ? "今天要完成的事项" : "记录当天的事情，好写日报",
                    text: $title
                )
                .textFieldStyle(.roundedBorder)

                Button {
                    addTask()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(DeliveryBarTheme.accent)
            }

            TextField("备注，可选", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.danger)
            }
        }
        .padding(10)
        .background(DeliveryBarTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DeliveryBarTheme.cardStroke)
        }
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                if selectedTasks.isEmpty {
                    ContentUnavailableView(
                        "暂无记录",
                        systemImage: "tray",
                        description: Text("记录当天的待办事项和工作日志。")
                    )
                    .padding(.vertical, 28)
                } else {
                    if !todoTasks.isEmpty {
                        sectionHeader(title: "待办", count: todoTasks.filter { !$0.isCompleted }.count, systemImage: "checkmark.circle")

                        ForEach(todoTasks) { task in
                            TodoTaskRow(task: task) {
                                task.updateCompletion(!task.isCompleted)
                                saveContext()
                            } onDelete: {
                                modelContext.delete(task)
                                saveContext()
                            }
                        }
                    }

                    if !logTasks.isEmpty {
                        sectionHeader(title: "日志", count: nil, systemImage: "doc.text")
                            .padding(.top, todoTasks.isEmpty ? 0 : 4)

                        ForEach(logTasks) { task in
                            LogTaskRow(task: task) {
                                modelContext.delete(task)
                                saveContext()
                            }
                        }
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: listHeight)
        .clipped()
    }

    private func sectionHeader(title: String, count: Int?, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(DeliveryBarTheme.softText)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DeliveryBarTheme.inkSoft)

            if let count, count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(DeliveryBarTheme.accent)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(DeliveryBarTheme.accentWash.opacity(0.5), in: Capsule())
            }
        }
        .padding(.horizontal, 4)
    }

    private func addTask() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            validationMessage = "内容不能为空"
            return
        }

        let task = TemporaryTask(
            title: normalizedTitle,
            category: category,
            note: normalizedNote,
            taskDate: selectedDate
        )
        modelContext.insert(task)
        title = ""
        note = ""
        validationMessage = nil
        cleanupExpiredTasks()
        saveContext()
    }

    private func resetCategoryToLogIfPossible() {
        guard !hasDraftInput else { return }
        category = .log
    }

    private func cleanupExpiredTasks() {
        let cutoffDate = oldestAllowedDate()
        temporaryTasks
            .filter { task in
                calendar.startOfDay(for: task.taskDate) < cutoffDate
                    && (task.category == .log || task.isCompleted)
            }
            .forEach { modelContext.delete($0) }
        saveContext()
    }

    private func ensureSelectedDateInRange() {
        let startOfSelectedDate = calendar.startOfDay(for: selectedDate)
        if !visibleDates.contains(where: { calendar.isDate($0, inSameDayAs: startOfSelectedDate) }) {
            selectedDate = calendar.startOfDay(for: Date())
        }
    }

    private func oldestAllowedDate() -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -6, to: today) ?? today
    }

    private func dayTitle(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "今天"
        }
        if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        return date.formatted(.dateTime.weekday(.narrow))
    }

    private func monthDayText(for date: Date) -> String {
        date.formatted(.dateTime.month(.defaultDigits).day())
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save model context: \(error)")
        }
    }
}

// MARK: - Category Picker

private struct CategoryPicker: View {
    @Binding var selection: TemporaryCategory

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TemporaryCategory.allCases) { cat in
                Button {
                    selection = cat
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: cat.systemImage)
                            .font(.system(size: 10))
                        Text(cat.title)
                            .font(.caption2)
                    }
                    .foregroundStyle(selection == cat ? DeliveryBarTheme.ink : DeliveryBarTheme.softText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(selection == cat ? DeliveryBarTheme.accentWash.opacity(0.5) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(DeliveryBarTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DeliveryBarTheme.cardStroke)
        }
    }
}

// MARK: - Todo Task Row

private struct TodoTaskRow: View {
    let task: TemporaryTask
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? DeliveryBarTheme.accent : DeliveryBarTheme.muted)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? DeliveryBarTheme.softText : DeliveryBarTheme.ink)
                    .lineLimit(1)

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.caption)
                        .foregroundStyle(DeliveryBarTheme.softText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isConfirmingDelete {
                Button("取消") {
                    withAnimation(.snappy(duration: 0.16)) {
                        isConfirmingDelete = false
                    }
                }
                .font(.caption2)
                .buttonStyle(.borderless)

                Button("删除", role: .destructive) {
                    onDelete()
                }
                .font(.caption2)
                .buttonStyle(.borderless)
            } else {
                Button("删除", role: .destructive) {
                    withAnimation(.snappy(duration: 0.16)) {
                        isConfirmingDelete.toggle()
                    }
                }
                .font(.caption2)
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(DeliveryBarTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DeliveryBarTheme.cardStroke)
        }
    }
}

// MARK: - Log Task Row

private struct LogTaskRow: View {
    let task: TemporaryTask
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundStyle(DeliveryBarTheme.softText)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(DeliveryBarTheme.ink)
                    .lineLimit(2)

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.caption)
                        .foregroundStyle(DeliveryBarTheme.softText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isConfirmingDelete {
                Button("取消") {
                    withAnimation(.snappy(duration: 0.16)) {
                        isConfirmingDelete = false
                    }
                }
                .font(.caption2)
                .buttonStyle(.borderless)

                Button("删除", role: .destructive) {
                    onDelete()
                }
                .font(.caption2)
                .buttonStyle(.borderless)
            } else {
                Button("删除", role: .destructive) {
                    withAnimation(.snappy(duration: 0.16)) {
                        isConfirmingDelete.toggle()
                    }
                }
                .font(.caption2)
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(DeliveryBarTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DeliveryBarTheme.cardStroke)
        }
    }
}
