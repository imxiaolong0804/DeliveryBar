//
//  TodoListView.swift
//  DeliveryBar
//

import SwiftData
import SwiftUI

struct TodoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TemporaryTask.updatedAt, order: .reverse) private var allTempTasks: [TemporaryTask]

    let listHeight: CGFloat
    @Binding var selectedDate: Date
    @Binding var noteExpanded: Bool

    @State private var title = ""
    @State private var note = ""
    @State private var validationMessage: String?

    private var calendar: Calendar { .current }

    /// 未完成的待办不分日期一直显示（收件箱语义）；日期条只筛「已完成」
    private var todoTasks: [TemporaryTask] {
        allTempTasks
            .filter { $0.category == .todo }
            .filter { task in
                if !task.isCompleted { return true }
                return calendar.isDate(task.taskDate, inSameDayAs: selectedDate)
            }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var pendingTasks: [TemporaryTask] {
        todoTasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [TemporaryTask] {
        todoTasks.filter { $0.isCompleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateSelector
            Divider()
            addForm
            Divider()
            taskList
        }
        .onAppear {
            ensureSelectedDateInRange()
        }
    }

    private var dateSelector: some View {
        DayStripSelector(selectedDate: $selectedDate)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .help("切换日期查看当天完成的待办；未完成的待办始终显示")
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(DeliveryBarTheme.accent)

                TextField("添加待办，回车提交", text: $title)
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

    private var taskList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if todoTasks.isEmpty {
                    emptyState
                } else {
                    ForEach(pendingTasks) { task in
                        taskRow(task)
                    }

                    if !completedTasks.isEmpty {
                        completedHeader

                        ForEach(completedTasks) { task in
                            taskRow(task)
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

    private func taskRow(_ task: TemporaryTask) -> some View {
        TodoTaskRow(task: task) {
            task.updateCompletion(!task.isCompleted)
            modelContext.saveChanges()
        } onDelete: {
            modelContext.delete(task)
            modelContext.saveChanges()
        }
    }

    private var completedHeader: some View {
        HStack(spacing: 8) {
            // 带上日期，说明这一段只是选中那天完成的，不是全部历史
            Text("\(selectedDayTitle)完成 \(completedTasks.count)")
                .font(DeliveryBarTheme.Typography.captionStrong)
                .foregroundStyle(DeliveryBarTheme.softText)

            VStack(spacing: 0) { Divider() }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(DeliveryBarTheme.muted)

            Text("暂无待办")
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            Text("在上方输入事项，回车即可添加")
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
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
            category: .todo,
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

    private var selectedDayTitle: String {
        if calendar.isDateInToday(selectedDate) { return "今天" }
        if calendar.isDateInYesterday(selectedDate) { return "昨天" }
        return selectedDate.formatted(.dateTime.month(.defaultDigits).day())
    }
}
