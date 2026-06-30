//
//  MenuBarView.swift
//  DeliveryBar
//

import SwiftData
import SwiftUI

struct MenuBarView: View {
    private enum Layout {
        static let panelWidth: CGFloat = 460
        static let minListHeight: CGFloat = 84
        static let maxListHeight: CGFloat = 280
        static let rowHeight: CGFloat = 76
        static let sectionHeaderHeight: CGFloat = 24
        static let verticalPadding: CGFloat = 12
        static let headerHeight: CGFloat = 54
        static let tabHeight: CGFloat = 44
        static let requirementStatusTabHeight: CGFloat = 42
        static let footerHeight: CGFloat = 50
        static let settingsContentHeight: CGFloat = 360

        // Temporary tasks: fixed parts
        static let tempDateSelectorHeight: CGFloat = 78
        static let tempAddFormHeight: CGFloat = 90
        static let tempRowHeight: CGFloat = 52
        static let tempSectionHeaderHeight: CGFloat = 22
        static let tempMinListHeight: CGFloat = 60
        static let tempMaxListHeight: CGFloat = 220

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
    @State private var selectedTempDate = Calendar.current.startOfDay(for: Date())
    @State private var editorRequest: RequirementEditorRequest?
    @State private var quickEntryEditorRequest: QuickEntryEditorRequest?

    private var activeRequirements: [Requirement] {
        requirements.filter { !$0.isArchived }
    }

    private var existingQuickEntryTags: [String] {
        let tags = Set(quickEntries.map(\.tag).filter { !$0.isEmpty })
        return tags.sorted()
    }

    private var selectedTempTasks: [TemporaryTask] {
        temporaryTasks
            .filter { Calendar.current.isDate($0.taskDate, inSameDayAs: selectedTempDate) }
    }

    private var tempTodoCount: Int {
        selectedTempTasks.filter { $0.category == .todo }.count
    }

    private var tempLogCount: Int {
        selectedTempTasks.filter { $0.category == .log }.count
    }

    private var tempSectionCount: Int {
        var count = 0
        if tempTodoCount > 0 { count += 1 }
        if tempLogCount > 0 { count += 1 }
        return count
    }

    private var filteredQuickEntries: [QuickEntry] {
        quickEntries.sorted { lhs, rhs in
            if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var archivedRequirements: [Requirement] {
        requirements.filter { $0.isArchived }
    }

    private var attentionCount: Int {
        requirements.filter {
            ReminderService.attentionReason(for: $0, remindersEnabled: remindersEnabled) != nil
        }.count
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

    private var mainPanelHeight: CGFloat {
        Layout.headerHeight + Layout.tabHeight + Layout.requirementStatusTabHeight + mainListHeight + Layout.footerHeight + 4
    }

    private var archivePanelHeight: CGFloat {
        Layout.headerHeight + Layout.tabHeight + archiveListHeight + Layout.footerHeight + 3
    }

    private var temporaryListHeight: CGFloat {
        let count = selectedTempTasks.count
        if count == 0 { return Layout.tempMinListHeight }
        let contentHeight = CGFloat(count) * Layout.tempRowHeight
            + CGFloat(tempSectionCount) * Layout.tempSectionHeaderHeight
            + Layout.verticalPadding
        return min(max(contentHeight, Layout.tempMinListHeight), Layout.tempMaxListHeight)
    }

    private var temporaryPanelHeight: CGFloat {
        Layout.headerHeight + Layout.tabHeight
            + Layout.tempDateSelectorHeight + 1
            + Layout.tempAddFormHeight + 20 + 1
            + temporaryListHeight
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
        case .temporary:
            temporaryPanelHeight
        case .quickMap:
            quickMapPanelHeight
        case .archive:
            archivePanelHeight
        case .settings:
            settingsPanelHeight
        }
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
            migrateLegacyUndeliveredRequirements()
            cleanupExpiredTemporaryTasks()
            resolveInitialRequirementStatusIfNeeded()
        }
        .onChange(of: currentTab) { _, newTab in
            if newTab == .temporary {
                cleanupExpiredTemporaryTasks()
            }
        }
    }

    private var tabbedPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(title: currentTab.title, subtitle: currentTabSubtitle)

            Divider()

            tabSelector

            Divider()

            tabContent

            Divider()

            tabFooter
        }
        .frame(width: Layout.panelWidth, height: tabPanelHeight)
        .background(DeliveryBarTheme.panelBackground)
        .tint(DeliveryBarTheme.accent)
    }

    private var tabSelector: some View {
        HStack(spacing: 6) {
            ForEach(MenuBarTab.allCases) { tab in
                Button {
                    currentTab = tab
                } label: {
                    let isSelected = currentTab == tab
                    Label(tab.title, systemImage: tab.systemImage)
                        .font(.caption)
                        .foregroundStyle(DeliveryBarTheme.pillForeground(isSelected: isSelected))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(DeliveryBarTheme.pillBackground(isSelected: isSelected), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(DeliveryBarTheme.pillStroke(isSelected: isSelected))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch currentTab {
        case .requirements:
            mainList
        case .temporary:
            TemporaryTasksView(listHeight: temporaryListHeight, selectedDate: $selectedTempDate)
                .frame(height: Layout.tempDateSelectorHeight + 1 + Layout.tempAddFormHeight + 20 + 1 + temporaryListHeight)
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
                .foregroundStyle(DeliveryBarTheme.ink)
                .frame(width: 32, height: 32)
                .background(DeliveryBarTheme.accentWash, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DeliveryBarTheme.ink.opacity(0.14))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
            }

            Spacer()

            if attentionCount > 0 {
                Label("\(attentionCount)", systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DeliveryBarTheme.danger, in: Capsule())
            }
        }
        .padding(12)
    }

    private var summaryText: String {
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
        case .temporary:
            "待办与工作日志"
        case .quickMap:
            quickEntries.isEmpty ? "保存常用的链接、脚本和文本片段" : "\(quickEntries.count) 个快捷录"
        case .archive:
            "\(archivedRequirements.count) 个已归档需求"
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

    private var requirementStatusTabs: some View {
        HStack(spacing: 6) {
            ForEach(RequirementStatus.mainList) { status in
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
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.pillForeground(isSelected: isSelected))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(DeliveryBarTheme.pillBackground(isSelected: isSelected), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DeliveryBarTheme.pillStroke(isSelected: isSelected))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
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
                                saveContext()
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
        Text(activeRequirements.isEmpty ? "等待您新建一个需求" : "\(selectedRequirementStatus.compactTitle)暂无需求")
            .font(.subheadline)
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

            Spacer()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DeliveryBarTheme.footerBackground)
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

    private func moveToNextStatus(_ requirement: Requirement) {
        guard let nextStatus = requirement.status.nextStatus else { return }
        requirement.updateStatus(nextStatus)
        saveContext()
    }

    private func updateStatus(_ requirement: Requirement, _ status: RequirementStatus) {
        requirement.updateStatus(status)
        if RequirementStatus.mainList.contains(status) {
            selectedRequirementStatus = status
        }
        saveContext()
    }

    private func deleteRequirement(_ requirement: Requirement) {
        modelContext.delete(requirement)
        saveContext()
    }

    private func listHeight(rowCount: Int, sectionCount: Int, isEmpty: Bool) -> CGFloat {
        if isEmpty {
            return 70
        }

        let contentHeight = CGFloat(rowCount) * Layout.rowHeight
            + CGFloat(sectionCount) * Layout.sectionHeaderHeight
            + Layout.verticalPadding
        return min(max(contentHeight, Layout.minListHeight), Layout.maxListHeight)
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save model context: \(error)")
        }
    }

    private func cleanupExpiredTemporaryTasks() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cutoffDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        temporaryTasks
            .filter { calendar.startOfDay(for: $0.taskDate) < cutoffDate }
            .forEach { modelContext.delete($0) }
        saveContext()
    }

    private func migrateLegacyUndeliveredRequirements() {
        let legacyRequirements = requirements.filter { $0.status == .developedNotDelivered }
        guard !legacyRequirements.isEmpty else { return }

        legacyRequirements.forEach {
            $0.statusRaw = RequirementStatus.waitingAcceptance.rawValue
        }
        saveContext()
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
}

enum MenuBarTab: String, CaseIterable, Identifiable {
    case requirements
    case temporary
    case quickMap
    case archive
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .requirements:
            "需求列表"
        case .temporary:
            "临时"
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
        case .temporary:
            "calendar.badge.clock"
        case .quickMap:
            "keyboard"
        case .archive:
            "archivebox"
        case .settings:
            "gearshape"
        }
    }
}

struct RequirementEditorRequest: Identifiable {
    let id = UUID()
    let requirement: Requirement?
}

struct RequirementSectionView: View {
    let status: RequirementStatus
    let requirements: [Requirement]
    let remindersEnabled: Bool
    let onEdit: (Requirement) -> Void
    let onChangeStatus: (Requirement, RequirementStatus) -> Void
    let onDelete: (Requirement) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(status.tintColor)
                    .frame(width: 6, height: 6)

                Text(status.compactTitle)
                    .font(.caption)
                    .fontWeight(.semibold)

                Text("\(requirements.count)")
                    .font(.caption)
                    .foregroundStyle(DeliveryBarTheme.softText)
                Spacer()
            }
            .padding(.horizontal, 2)

            VStack(spacing: 5) {
                ForEach(requirements) { requirement in
                    RequirementRowView(
                        requirement: requirement,
                        remindersEnabled: remindersEnabled,
                        onEdit: { onEdit(requirement) },
                        onChangeStatus: { onChangeStatus(requirement, $0) },
                        onDelete: { onDelete(requirement) },
                        onRestore: nil
                    )
                }
            }
        }
    }
}
