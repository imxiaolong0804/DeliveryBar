//
//  MenuBarView.swift
//  DeliveryBar
//

import SwiftData
import SwiftUI

struct MenuBarView: View {
    private let onOpenJSONFormatter: () -> Void
    private let onOpenMemo: () -> Void
    private let onPreferredSizeChange: (CGSize) -> Void

    init(
        onOpenJSONFormatter: @escaping () -> Void = {},
        onOpenMemo: @escaping () -> Void = {},
        onPreferredSizeChange: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.onOpenJSONFormatter = onOpenJSONFormatter
        self.onOpenMemo = onOpenMemo
        self.onPreferredSizeChange = onPreferredSizeChange
    }

    private enum Layout {
        static let panelWidth: CGFloat = 460
        static let minListHeight: CGFloat = 84
        static let maxListHeight: CGFloat = 320
        static let rowHeight: CGFloat = 118
        static let rowSpacing: CGFloat = 8
        static let listVerticalPadding: CGFloat = 16
        static let sectionHeaderHeight: CGFloat = 24
        static let verticalPadding: CGFloat = 12
        static let headerHeight: CGFloat = 54
        static let tabHeight: CGFloat = 44
        // 原来 68 含一行说明文字（caption2 13 + VStack 间距 6），去掉后按差值下调
        static let requirementStatusTabHeight: CGFloat = 49
        static let searchBarHeight: CGFloat = 45
        static let footerHeight: CGFloat = 50
        static let settingsContentHeight: CGFloat = 360

        // Todo / Logs 共用：轻量输入行与备注展开的估算高度
        static let addFormHeight: CGFloat = 38
        static let noteFieldExtraHeight: CGFloat = 32
        static let taskRowHeight: CGFloat = 34
        static let taskRowNoteExtra: CGFloat = 17
        static let taskRowSpacing: CGFloat = 2

        // Todo tab
        static let todoToolbarHeight: CGFloat = 45
        static let todoCompletedHeaderHeight: CGFloat = 28
        static let todoMinListHeight: CGFloat = 130
        static let todoMaxListHeight: CGFloat = 330

        // Logs tab
        static let logToolbarHeight: CGFloat = 45
        static let logMinListHeight: CGFloat = 130
        static let logMaxListHeight: CGFloat = 340

        // Week view
        static let logWeekToolbarHeight: CGFloat = 38
        static let logWeekDayHeaderHeight: CGFloat = 28
        static let logWeekMinContentHeight: CGFloat = 180
        static let logWeekMaxContentHeight: CGFloat = 430

        // Quick entries: fixed parts
        static let quickSearchBarHeight: CGFloat = 44
        static let quickTypeFilterHeight: CGFloat = 38
        static let quickRowHeight: CGFloat = 68
        static let quickMinListHeight: CGFloat = 60
        static let quickMaxListHeight: CGFloat = 260
    }

    @Environment(\.modelContext) private var modelContext
    @AppStorage("remindersEnabled") private var remindersEnabled = true
    @Query(sort: \Requirement.updatedAt, order: .reverse) private var requirements: [Requirement]
    @Query(sort: \TemporaryTask.updatedAt, order: .reverse) private var temporaryTasks: [TemporaryTask]
    @Query private var quickEntries: [QuickEntry]

    @State private var currentTab: MenuBarTab = .requirements
    @State private var selectedRequirementStatus: RequirementStatus = .developing
    @State private var hasResolvedInitialRequirementStatus = false
    @State private var selectedTodoDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedLogDate = Calendar.current.startOfDay(for: Date())
    @State private var logViewMode: LogViewMode = .day
    @State private var todoNoteExpanded = false
    @State private var logNoteExpanded = false
    @State private var editorRequest: RequirementEditorRequest?
    @State private var quickEntryEditorRequest: QuickEntryEditorRequest?
    @State private var showsAttentionPopover = false
    @State private var showsRequirementSearch = false
    @State private var requirementSearchText = ""

    /// 需求列表与归档共用的搜索过滤（关注数不受影响，始终基于全量）
    private var searchedRequirements: [Requirement] {
        let query = requirementSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return requirements }
        return requirements.filter { $0.matches(query) }
    }

    private var isSearchingRequirements: Bool {
        showsRequirementSearch
            && !requirementSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var supportsRequirementSearch: Bool {
        currentTab == .requirements || currentTab == .archive
    }

    private var activeRequirements: [Requirement] {
        searchedRequirements.filter { !$0.isArchived }
    }

    private var existingQuickEntryTags: [String] {
        let tags = Set(quickEntries.map(\.tag).filter { !$0.isEmpty })
        return tags.sorted()
    }

    private var allTodoTasks: [TemporaryTask] {
        temporaryTasks.filter { $0.category == .todo }
    }

    private var uncompletedTodoCount: Int {
        allTodoTasks.filter { !$0.isCompleted }.count
    }

    private var visibleTodoTasks: [TemporaryTask] {
        allTodoTasks.filter { task in
            if !task.isCompleted { return true }
            return Calendar.current.isDate(task.taskDate, inSameDayAs: selectedTodoDate)
        }
        .sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var selectedLogTasks: [TemporaryTask] {
        temporaryTasks.filter { task in
            task.category == .log
                && Calendar.current.isDate(task.taskDate, inSameDayAs: selectedLogDate)
        }
    }

    private var weekLogTasks: [TemporaryTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        return temporaryTasks.filter { task in
            task.category == .log && task.taskDate >= sevenDaysAgo && task.taskDate <= today
        }
        .sorted { $0.taskDate > $1.taskDate || ($0.taskDate == $1.taskDate && $0.updatedAt > $1.updatedAt) }
    }

    private var filteredQuickEntries: [QuickEntry] {
        quickEntries.sorted { lhs, rhs in
            if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var archivedRequirements: [Requirement] {
        searchedRequirements.filter { $0.isArchived }
    }

    private var attentionItems: [(requirement: Requirement, reason: String)] {
        requirements.compactMap { requirement in
            guard let reason = ReminderService.attentionReason(for: requirement, remindersEnabled: remindersEnabled) else {
                return nil
            }
            return (requirement, reason)
        }
    }

    private var attentionCount: Int {
        attentionItems.count
    }

    private var selectedRequirements: [Requirement] {
        requirements(for: selectedRequirementStatus)
    }

    private var mainListHeight: CGFloat {
        listHeight(rowCount: selectedRequirements.count, sectionCount: 0, isEmpty: selectedRequirements.isEmpty)
    }

    private var archiveListHeight: CGFloat {
        listHeight(rowCount: archivedRequirements.count, sectionCount: archivedRequirements.isEmpty ? 0 : 1, isEmpty: archivedRequirements.isEmpty)
    }

    private var requirementSearchBarHeight: CGFloat {
        showsRequirementSearch ? Layout.searchBarHeight + 1 : 0
    }

    private var mainPanelHeight: CGFloat {
        Layout.headerHeight + Layout.tabHeight + requirementSearchBarHeight
            + Layout.requirementStatusTabHeight + mainListHeight + Layout.footerHeight + 4
    }

    private var archivePanelHeight: CGFloat {
        Layout.headerHeight + Layout.tabHeight + requirementSearchBarHeight
            + archiveListHeight + Layout.footerHeight + 3
    }

    private func estimatedRowsHeight(for tasks: [TemporaryTask]) -> CGFloat {
        let rows = tasks.reduce(CGFloat(0)) { partial, task in
            partial + Layout.taskRowHeight + (task.note.isEmpty ? 0 : Layout.taskRowNoteExtra)
        }
        return rows + CGFloat(max(tasks.count - 1, 0)) * Layout.taskRowSpacing
    }

    private var todoContentChromeHeight: CGFloat {
        Layout.todoToolbarHeight + 1
            + Layout.addFormHeight + (todoNoteExpanded ? Layout.noteFieldExtraHeight : 0) + 1
    }

    private var todoListHeight: CGFloat {
        let tasks = visibleTodoTasks
        if tasks.isEmpty { return Layout.todoMinListHeight }
        let completedHeader: CGFloat = tasks.contains(where: \.isCompleted) ? Layout.todoCompletedHeaderHeight : 0
        let contentHeight = estimatedRowsHeight(for: tasks) + completedHeader + Layout.verticalPadding
        return min(max(contentHeight, Layout.todoMinListHeight), Layout.todoMaxListHeight)
    }

    private var todoPanelHeight: CGFloat {
        Layout.headerHeight + Layout.tabHeight
            + todoContentChromeHeight
            + todoListHeight
            + Layout.footerHeight + 3
    }

    private var logListHeight: CGFloat {
        let tasks = selectedLogTasks
        if tasks.isEmpty { return Layout.logMinListHeight }
        let contentHeight = estimatedRowsHeight(for: tasks) + Layout.verticalPadding
        return min(max(contentHeight, Layout.logMinListHeight), Layout.logMaxListHeight)
    }

    private var logWeekListHeight: CGFloat {
        let tasks = weekLogTasks
        if tasks.isEmpty { return Layout.logWeekMinContentHeight }
        let dayCount = Set(tasks.map { Calendar.current.startOfDay(for: $0.taskDate) }).count
        let contentHeight = estimatedRowsHeight(for: tasks)
            + CGFloat(dayCount) * Layout.logWeekDayHeaderHeight
            + Layout.verticalPadding
        return min(max(contentHeight, Layout.logWeekMinContentHeight), Layout.logWeekMaxContentHeight)
    }

    private var logPanelContentHeight: CGFloat {
        switch logViewMode {
        case .day:
            return Layout.logToolbarHeight + 1
                + Layout.addFormHeight + (logNoteExpanded ? Layout.noteFieldExtraHeight : 0) + 1
                + logListHeight
        case .week:
            return Layout.logWeekToolbarHeight + 1
                + logWeekListHeight
        }
    }

    private var logPanelHeight: CGFloat {
        Layout.headerHeight + Layout.tabHeight
            + logPanelContentHeight
            + Layout.footerHeight + 3
    }

    private var settingsPanelHeight: CGFloat {
        Layout.headerHeight + Layout.tabHeight + Layout.settingsContentHeight + Layout.footerHeight + 3
    }

    private var quickMapListHeight: CGFloat {
        let count = filteredQuickEntries.count
        if count == 0 { return Layout.quickMinListHeight }
        let contentHeight = CGFloat(count) * Layout.quickRowHeight + Layout.verticalPadding
        return min(max(contentHeight, Layout.quickMinListHeight), Layout.quickMaxListHeight)
    }

    private var quickMapPanelHeight: CGFloat {
        Layout.headerHeight + Layout.tabHeight
            + Layout.quickSearchBarHeight + 20
            + 1 + Layout.quickTypeFilterHeight
            + 1 + quickMapListHeight
            + Layout.footerHeight + 3
    }

    private var tabPanelHeight: CGFloat {
        switch currentTab {
        case .requirements:
            mainPanelHeight
        case .todo:
            todoPanelHeight
        case .log:
            logPanelHeight
        case .quickMap:
            quickMapPanelHeight
        case .archive:
            archivePanelHeight
        case .settings:
            settingsPanelHeight
        }
    }

    private var preferredPanelHeight: CGFloat {
        if editorRequest != nil {
            return 480
        }

        if quickEntryEditorRequest != nil {
            return 420
        }

        return tabPanelHeight
    }

    var body: some View {
        Group {
            if let editorRequest {
                RequirementEditorView(
                    requirement: editorRequest.requirement,
                    onCancel: { self.editorRequest = nil },
                    onComplete: { self.editorRequest = nil }
                )
            } else if let quickEntryEditorRequest {
                QuickEntryEditorView(
                    entry: quickEntryEditorRequest.entry,
                    existingKeys: quickEntryEditorRequest.existingKeys,
                    existingTags: existingQuickEntryTags,
                    onCancel: { self.quickEntryEditorRequest = nil },
                    onComplete: { self.quickEntryEditorRequest = nil }
                )
            } else {
                tabbedPage
            }
        }
        .frame(width: Layout.panelWidth)
        .onAppear {
            MaintenanceService.run(in: modelContext)
            resolveInitialRequirementStatusIfNeeded()
            notifyPreferredSize()
        }
        .onChange(of: currentTab) { _, newTab in
            // 面板可能连开几天不退出，切到临时任务时补跑一次滚动窗口清理
            if newTab == .log || newTab == .todo {
                MaintenanceService.run(in: modelContext)
            }
        }
        .onChange(of: preferredPanelHeight) { _, _ in
            notifyPreferredSize()
        }
    }

    private var tabbedPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(title: currentTab.title, subtitle: currentTabSubtitle)

            Divider()

            tabSelector

            Divider()

            if showsRequirementSearch, supportsRequirementSearch {
                requirementSearchBar

                Divider()
            }

            tabContent

            Divider()

            tabFooter
        }
        .frame(width: Layout.panelWidth, height: tabPanelHeight)
        .background(DeliveryBarTheme.panelBackground)
        .tint(DeliveryBarTheme.accent)
    }

    /// 归档与设置是低频入口，只留图标，把宽度让给高频 tab
    private var tabSelector: some View {
        HStack(spacing: 6) {
            ForEach(MenuBarTab.allCases) { tab in
                Button {
                    currentTab = tab
                } label: {
                    let isSelected = currentTab == tab
                    Group {
                        if tab.showsTitleInTabBar {
                            Label(tab.title, systemImage: tab.systemImage)
                                .labelStyle(.titleAndIcon)
                        } else {
                            Image(systemName: tab.systemImage)
                        }
                    }
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.pillForeground(isSelected: isSelected))
                    .selectablePill(isSelected: isSelected, verticalPadding: 5)
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: !tab.showsTitleInTabBar, vertical: false)
                .help(tab.title)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var requirementSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(DeliveryBarTheme.softText)

            TextField("搜索标题、描述、备注、PM 或测试", text: $requirementSearchText)
                .textFieldStyle(.plain)
                .font(DeliveryBarTheme.Typography.caption)

            if !requirementSearchText.isEmpty {
                Button {
                    requirementSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DeliveryBarTheme.softText)
                }
                .buttonStyle(.borderless)
            }
        }
        .deliveryCard(padding: 6)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch currentTab {
        case .requirements:
            mainList
        case .todo:
            TodoListView(
                listHeight: todoListHeight,
                selectedDate: $selectedTodoDate,
                noteExpanded: $todoNoteExpanded
            )
            .frame(height: todoContentChromeHeight + todoListHeight, alignment: .top)
        case .log:
            TemporaryTasksView(
                listHeight: logListHeight,
                weekListHeight: logWeekListHeight,
                selectedDate: $selectedLogDate,
                viewMode: $logViewMode,
                noteExpanded: $logNoteExpanded
            )
            .frame(height: logPanelContentHeight, alignment: .top)
        case .quickMap:
            QuickEntryListView(listHeight: quickMapListHeight, onEdit: { entry in
                quickEntryEditorRequest = QuickEntryEditorRequest(
                    entry: entry,
                    existingKeys: quickEntries.filter { $0.id != entry.id }.map(\.key)
                )
            })
                .frame(height: Layout.quickSearchBarHeight + 20 + 1 + Layout.quickTypeFilterHeight + 1 + quickMapListHeight)
        case .archive:
            archiveList
        case .settings:
            SettingsView(showsNavigation: false)
                .frame(height: Layout.settingsContentHeight)
        }
    }

    private func header(title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: currentTab.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DeliveryBarTheme.inkSoft)
                .frame(width: 32, height: 32)
                .background(DeliveryBarTheme.quietFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DeliveryBarTheme.Typography.windowTitle)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Text(subtitle)
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
            }

            Spacer()

            if supportsRequirementSearch {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        showsRequirementSearch.toggle()
                    }
                    if !showsRequirementSearch {
                        requirementSearchText = ""
                    }
                } label: {
                    Image(systemName: showsRequirementSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(showsRequirementSearch ? DeliveryBarTheme.accent : DeliveryBarTheme.softText)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("f", modifiers: .command)
                .help("搜索需求（⌘F）")
            }

            if attentionCount > 0 {
                Button {
                    showsAttentionPopover.toggle()
                } label: {
                    Label("\(attentionCount)", systemImage: "exclamationmark.circle.fill")
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(.white)
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DeliveryBarTheme.danger, in: Capsule())
                }
                .buttonStyle(.plain)
                .help("逾期、今天到期或长期未推进的需求数，点击查看明细")
                .popover(isPresented: $showsAttentionPopover, arrowEdge: .bottom) {
                    attentionListPopover
                }
            }
        }
        .padding(12)
    }

    private var attentionListPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("需要关注的需求")
                .font(DeliveryBarTheme.Typography.captionStrong)
                .foregroundStyle(DeliveryBarTheme.ink)

            Text("逾期 / 今天到期，或在当前阶段停留过久")
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(attentionItems, id: \.requirement.id) { item in
                        attentionRow(item.requirement, reason: item.reason)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .padding(12)
        .frame(width: 320)
    }

    private func attentionRow(_ requirement: Requirement, reason: String) -> some View {
        Button {
            showsAttentionPopover = false
            currentTab = .requirements
            // 带着搜索条件跳过去可能什么都看不到，直接清掉
            requirementSearchText = ""
            if RequirementStatus.mainList.contains(requirement.status) {
                selectedRequirementStatus = requirement.status
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(requirement.priority.rankTitle)
                        .font(DeliveryBarTheme.Typography.captionStrong)
                        .foregroundStyle(requirement.priority.tintColor)

                    Text(requirement.title)
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(DeliveryBarTheme.ink)
                        .lineLimit(1)

                    Spacer()
                }

                HStack(spacing: 6) {
                    Text(requirement.status.compactTitle)
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(requirement.status.tintColor)

                    Text(reason)
                        .font(DeliveryBarTheme.Typography.captionStrong)
                        .foregroundStyle(DeliveryBarTheme.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DeliveryBarTheme.danger.opacity(0.10), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .deliveryCard(padding: 8)
            .hoverHighlight(cornerRadius: DeliveryBarTheme.Radius.card)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("复制标题") { Clipboard.copy(requirement.title) }
        }
    }

    private var summaryText: String {
        if isSearchingRequirements {
            return activeRequirements.isEmpty ? "没有匹配的需求" : "\(activeRequirements.count) 条匹配"
        }
        if activeRequirements.isEmpty {
            return "暂无进行中的需求"
        }
        if attentionCount > 0 {
            return "\(attentionCount) 个需求需要关注"
        }
        return "\(activeRequirements.count) 个需求正在跟踪"
    }

    private var currentTabSubtitle: String {
        switch currentTab {
        case .requirements:
            summaryText
        case .todo:
            if uncompletedTodoCount > 0 {
                "\(uncompletedTodoCount) 个未完成"
            } else if visibleTodoTasks.isEmpty {
                "记录今天要完成的事"
            } else {
                "全部完成 🎉"
            }
        case .log:
            switch logViewMode {
            case .day: "\(selectedLogTasks.count) 条日志"
            case .week: "\(weekLogTasks.count) 条日志（近7天）"
            }
        case .quickMap:
            quickEntries.isEmpty ? "保存常用的链接、脚本和文本片段" : "\(quickEntries.count) 个快捷录"
        case .archive:
            if isSearchingRequirements {
                archivedRequirements.isEmpty ? "没有匹配的归档需求" : "\(archivedRequirements.count) 条匹配"
            } else {
                "\(archivedRequirements.count) 个已归档需求"
            }
        case .settings:
            "提醒与偏好设置"
        }
    }

    private var mainList: some View {
        VStack(alignment: .leading, spacing: 0) {
            requirementStatusTabs

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if selectedRequirements.isEmpty {
                        emptyState
                    } else {
                        ForEach(selectedRequirements) { requirement in
                            RequirementRowView(
                                requirement: requirement,
                                remindersEnabled: remindersEnabled,
                                onEdit: { editorRequest = RequirementEditorRequest(requirement: requirement) },
                                onChangeStatus: { updateStatus(requirement, $0) },
                                onDelete: { deleteRequirement(requirement) },
                                onRestore: nil
                            )
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: mainListHeight)
            .clipped()
        }
    }

    /// 胶囊之间的箭头本身就表达了流转方向，不再额外占一行说明文字
    private var requirementStatusTabs: some View {
        HStack(spacing: 4) {
            ForEach(Array(RequirementStatus.mainList.enumerated()), id: \.element.id) { index, status in
                Button {
                    selectedRequirementStatus = status
                } label: {
                    let isSelected = selectedRequirementStatus == status
                    HStack(spacing: 4) {
                        Text(status.compactTitle)
                            .lineLimit(1)

                        Text("\(requirements(for: status).count)")
                            .foregroundStyle(isSelected ? DeliveryBarTheme.inkSoft : DeliveryBarTheme.softText)
                    }
                    .font(DeliveryBarTheme.Typography.caption)
                    .foregroundStyle(DeliveryBarTheme.pillForeground(isSelected: isSelected))
                    .selectablePill(isSelected: isSelected, verticalPadding: 5)
                }
                .buttonStyle(.plain)

                if index < RequirementStatus.mainList.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DeliveryBarTheme.softText.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .help("点击阶段筛选需求，卡片右侧按钮推进到下一步")
    }

    private var archiveList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if archivedRequirements.isEmpty {
                    ContentUnavailableView(
                        "暂无归档需求",
                        systemImage: "archivebox",
                        description: Text("完成后的需求会出现在这里。")
                    )
                    .padding(.vertical, 28)
                } else {
                    ForEach(archivedRequirements) { requirement in
                        RequirementRowView(
                            requirement: requirement,
                            remindersEnabled: false,
                            onEdit: { editorRequest = RequirementEditorRequest(requirement: requirement) },
                            onChangeStatus: { updateStatus(requirement, $0) },
                            onDelete: { deleteRequirement(requirement) },
                            onRestore: {
                                requirement.updateStatus(.completed)
                                modelContext.saveChanges()
                            }
                        )
                    }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: archiveListHeight)
        .clipped()
    }

    private var emptyState: some View {
        Text(emptyStateText)
            .font(DeliveryBarTheme.Typography.caption)
            .foregroundStyle(DeliveryBarTheme.softText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
    }

    private var tabFooter: some View {
        HStack(spacing: 8) {
            if currentTab == .requirements {
                Button {
                    editorRequest = RequirementEditorRequest(requirement: nil)
                } label: {
                    Label("新增需求", systemImage: "plus")
                }
            }

            if currentTab == .quickMap {
                Button {
                    quickEntryEditorRequest = QuickEntryEditorRequest(
                        entry: nil,
                        existingKeys: quickEntries.map(\.key)
                    )
                } label: {
                    Label("新增快捷录", systemImage: "plus")
                }
            }

            Button {
                onOpenMemo()
            } label: {
                Label("备忘", systemImage: "note.text")
            }
            .help("打开备忘窗口（⌘⇧N 直接新建）")

            Button {
                onOpenJSONFormatter()
            } label: {
                Label("JSON", systemImage: "curlybraces")
            }
            .help("JSON 格式化与对比（⌘⇧J）")

            Spacer()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyStateText: String {
        if isSearchingRequirements {
            return "没有匹配的需求，换个关键词试试"
        }
        return activeRequirements.isEmpty ? "等待您新建一个需求" : "\(selectedRequirementStatus.compactTitle)暂无需求"
    }

    private func requirements(for status: RequirementStatus) -> [Requirement] {
        activeRequirements
            .filter { $0.status == status }
            .sorted { lhs, rhs in
                if lhs.priorityRaw != rhs.priorityRaw {
                    return lhs.priorityRaw > rhs.priorityRaw
                }
                return lhs.statusChangedAt > rhs.statusChangedAt
            }
    }

    private func updateStatus(_ requirement: Requirement, _ status: RequirementStatus) {
        requirement.updateStatus(status)
        if RequirementStatus.mainList.contains(status) {
            selectedRequirementStatus = status
        }
        modelContext.saveChanges()
    }

    private func deleteRequirement(_ requirement: Requirement) {
        modelContext.delete(requirement)
        modelContext.saveChanges()
    }

    private func listHeight(rowCount: Int, sectionCount: Int, isEmpty: Bool) -> CGFloat {
        if isEmpty {
            return 70
        }

        let rowSpacing = CGFloat(max(rowCount - 1, 0)) * Layout.rowSpacing
        let contentHeight = CGFloat(rowCount) * Layout.rowHeight
            + rowSpacing
            + CGFloat(sectionCount) * Layout.sectionHeaderHeight
            + Layout.listVerticalPadding
        return min(max(contentHeight, Layout.minListHeight), Layout.maxListHeight)
    }

    private func resolveInitialRequirementStatusIfNeeded() {
        guard !hasResolvedInitialRequirementStatus else { return }
        hasResolvedInitialRequirementStatus = true

        if !requirements(for: .developing).isEmpty {
            selectedRequirementStatus = .developing
            return
        }

        if let firstNonEmptyStatus = RequirementStatus.mainList.first(where: { !requirements(for: $0).isEmpty }) {
            selectedRequirementStatus = firstNonEmptyStatus
        } else {
            selectedRequirementStatus = .developing
        }
    }

    private func notifyPreferredSize() {
        onPreferredSizeChange(CGSize(width: Layout.panelWidth, height: preferredPanelHeight))
    }
}

enum LogViewMode: String, CaseIterable {
    case day
    case week
}

enum MenuBarTab: String, CaseIterable, Identifiable {
    case requirements
    case todo
    case log
    case quickMap
    case archive
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .requirements:
            "需求列表"
        case .todo:
            "待办"
        case .log:
            "日志"
        case .quickMap:
            "快捷录"
        case .archive:
            "归档"
        case .settings:
            "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .requirements:
            "checklist"
        case .todo:
            "checkmark.circle"
        case .log:
            "doc.text"
        case .quickMap:
            "keyboard"
        case .archive:
            "archivebox"
        case .settings:
            "gearshape"
        }
    }

    /// 归档、设置属于低频入口，在 tab 栏里只显示图标
    var showsTitleInTabBar: Bool {
        switch self {
        case .requirements, .todo, .log, .quickMap:
            true
        case .archive, .settings:
            false
        }
    }
}

struct RequirementEditorRequest: Identifiable {
    let id = UUID()
    let requirement: Requirement?
}

