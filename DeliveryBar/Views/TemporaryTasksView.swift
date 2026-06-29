//
//  TemporaryTasksView.swift
//  DeliveryBar
//

import SwiftData
import SwiftUI

struct TemporaryTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TemporaryTask.updatedAt, order: .reverse) private var temporaryTasks: [TemporaryTask]

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var title = ""
    @State private var note = ""
    @State private var typeTitle = TemporaryTaskType.defaultTitle
    @State private var validationMessage: String?

    private var calendar: Calendar { .current }

    private var visibleDates: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private var selectedTasks: [TemporaryTask] {
        temporaryTasks
            .filter { calendar.isDate($0.taskDate, inSameDayAs: selectedDate) }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted {
                    return !lhs.isCompleted
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var summaryText: String {
        let unfinishedCount = selectedTasks.filter { !$0.isCompleted }.count
        if selectedTasks.isEmpty {
            return "当天没有临时事项"
        }
        if unfinishedCount == 0 {
            return "\(selectedTasks.count) 个临时事项已完成"
        }
        return "\(unfinishedCount) 个临时事项待处理"
    }

    private var typeSuggestions: [String] {
        var suggestions = TemporaryTaskType.defaultTitles
        let historicalTypes = temporaryTasks.map(\.typeTitle)

        for type in historicalTypes {
            if !suggestions.contains(where: { $0.caseInsensitiveCompare(type) == .orderedSame }) {
                suggestions.append(type)
            }
        }
        return suggestions
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
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(visibleDates, id: \.self) { date in
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 2) {
                            Text(dayTitle(for: date))
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text(monthDayText(for: date))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(calendar.isDate(date, inSameDayAs: selectedDate) ? DeliveryBarTheme.accent : .secondary)
                }
            }
        }
        .padding(12)
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                TemporaryTypeField(
                    text: $typeTitle,
                    suggestions: typeSuggestions
                )

                TextField("记录 case 排查、联调或临时事项", text: $title)
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
                    .foregroundStyle(.red)
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
                        "暂无临时事项",
                        systemImage: "tray",
                        description: Text("记录当天的 case 排查、联调和零散问题。")
                    )
                    .padding(.vertical, 28)
                } else {
                    ForEach(selectedTasks) { task in
                        TemporaryTaskRow(task: task) {
                            task.updateCompletion(!task.isCompleted)
                            saveContext()
                        } onDelete: {
                            modelContext.delete(task)
                            saveContext()
                        }
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: 220)
        .clipped()
    }

    private func addTask() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedType = TemporaryTaskType.storageValue(for: typeTitle)
        guard !normalizedTitle.isEmpty else {
            validationMessage = "临时事项不能为空"
            return
        }

        let task = TemporaryTask(
            title: normalizedTitle,
            typeTitle: normalizedType,
            note: normalizedNote,
            taskDate: selectedDate
        )
        modelContext.insert(task)
        title = ""
        note = ""
        typeTitle = normalizedType
        validationMessage = nil
        cleanupExpiredTasks()
        saveContext()
    }

    private func cleanupExpiredTasks() {
        let cutoffDate = oldestAllowedDate()
        temporaryTasks
            .filter { calendar.startOfDay(for: $0.taskDate) < cutoffDate }
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

private struct TemporaryTaskRow: View {
    let task: TemporaryTask
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? DeliveryBarTheme.accent : .secondary)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.typeTitle)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(DeliveryBarTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DeliveryBarTheme.accent.opacity(0.12), in: Capsule())

                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                }

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button("删除", role: .destructive, action: onDelete)
                .font(.caption2)
                .buttonStyle(.borderless)
        }
        .padding(8)
        .background(DeliveryBarTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DeliveryBarTheme.cardStroke)
        }
    }
}

private struct TemporaryTypeField: View {
    @Binding var text: String
    let suggestions: [String]
    @State private var isShowingSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                TextField("类型", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 92)

                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        isShowingSuggestions.toggle()
                    }
                } label: {
                    Image(systemName: isShowingSuggestions ? "chevron.up.circle" : "chevron.down.circle")
                        .font(.system(size: 15))
                }
                .buttonStyle(.borderless)
                .frame(width: 24)
            }

            if isShowingSuggestions {
                suggestionChips
            }
        }
        .frame(width: 122, alignment: .leading)
    }

    @ViewBuilder
    private var suggestionChips: some View {
        if suggestions.isEmpty {
            Text("暂无类型")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 5)], alignment: .leading, spacing: 5) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        text = suggestion
                        withAnimation(.snappy(duration: 0.16)) {
                            isShowingSuggestions = false
                        }
                    }
                    .font(.caption2)
                    .lineLimit(1)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}
