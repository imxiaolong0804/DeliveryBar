//
//  MemoWindowView.swift
//  DeliveryBar
//
//  备忘独立窗口：左边列表和搜索，右边正文读写。
//  刻意不放进菜单栏面板——那个面板点一下别的 App 就收起，写长文会丢内容。
//

import AppKit
import Combine
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 面板控制器向窗口内部下达的指令（目前只有「快捷键新建」）
final class MemoWindowCommands: ObservableObject {
    @Published var composeToken: UUID?

    func requestCompose() {
        composeToken = UUID()
    }
}

struct MemoWindowView: View {
    private enum Layout {
        static let minWidth: CGFloat = 680
        static let minHeight: CGFloat = 420
        static let listWidth: CGFloat = 260
        static let autosaveDelay: Duration = .milliseconds(600)
    }

    @ObservedObject var commands: MemoWindowCommands
    var onPinnedChange: (Bool) -> Void = { _ in }
    var onClose: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]

    @StateObject private var editorController = MemoEditorController()

    @State private var selectedID: UUID?
    @State private var searchText = ""
    @State private var kindFilter: MemoKind?
    @State private var showsTrash = false
    @State private var isWindowPinned = false
    @State private var draftTitle = ""
    @State private var draftContent = ""
    @State private var draftTag = ""
    @State private var statusText: String?
    @State private var handledComposeToken: UUID?

    // MARK: Derived

    private var liveMemos: [Memo] {
        memos.filter { !$0.isDeleted }
    }

    private var trashedMemos: [Memo] {
        memos.filter(\.isDeleted)
    }

    private var visibleMemos: [Memo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var pool: [Memo] = showsTrash ? trashedMemos : liveMemos

        if let kindFilter {
            pool = pool.filter { (memo: Memo) in memo.kind == kindFilter }
        }
        if !query.isEmpty {
            pool = pool.filter { (memo: Memo) in memo.matches(query) }
        }

        if showsTrash {
            return pool.sorted { (lhs: Memo, rhs: Memo) in
                (lhs.deletedAt ?? .distantPast) > (rhs.deletedAt ?? .distantPast)
            }
        }

        return pool.sorted { (lhs: Memo, rhs: Memo) in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private var selectedMemo: Memo? {
        guard let selectedID else { return nil }
        return memos.first { $0.id == selectedID }
    }

    /// 任一草稿字段变化都要重新排自动保存的队
    private var draftSignature: String {
        [selectedID?.uuidString ?? "", draftTitle, draftTag, draftContent].joined(separator: "\u{1}")
    }

    // MARK: Body

    var body: some View {
        HStack(spacing: 0) {
            listPane
                .frame(width: Layout.listWidth)

            Divider()

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: Layout.minWidth,
            maxWidth: .infinity,
            minHeight: Layout.minHeight,
            maxHeight: .infinity
        )
        .background(DeliveryBarTheme.panelBackground)
        .tint(DeliveryBarTheme.accent)
        .onAppear {
            onPinnedChange(isWindowPinned)
            if selectedID == nil {
                selectedID = visibleMemos.first?.id
                loadDraft()
            }
            // 首次按 ⌘⇧N 时窗口和这个视图是同一轮创建出来的，
            // requestCompose 可能赶在 onChange 注册之前，这里补一次
            handleComposeIfNeeded()
        }
        .onChange(of: isWindowPinned) { _, newValue in
            onPinnedChange(newValue)
        }
        .onChange(of: commands.composeToken) { _, _ in
            handleComposeIfNeeded()
        }
        .task(id: draftSignature) {
            try? await Task.sleep(for: Layout.autosaveDelay)
            guard !Task.isCancelled else { return }
            flush(announcing: true)
        }
        // 停手就存已经覆盖大多数情况，这两个是兜底：切走窗口、退出应用
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            flush()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            flush()
        }
    }

    // MARK: List pane

    private var listPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchBar
                .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
                .padding(.top, DeliveryBarTheme.Spacing.lg)
                .padding(.bottom, DeliveryBarTheme.Spacing.md)

            Divider()

            memoList

            Divider()

            listFooter
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(DeliveryBarTheme.softText)

            TextField("搜索标题和正文", text: $searchText)
                .textFieldStyle(.plain)
                .font(DeliveryBarTheme.Typography.callout)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DeliveryBarTheme.softText)
                }
                .buttonStyle(.plain)
            }

            kindFilterMenu
        }
        .deliveryCard(padding: 6)
    }

    /// 原来是四个全宽胶囊平铺一整行，四条描边压着列表。
    /// 筛选是低频操作，收进搜索框里一个图标就够。
    private var kindFilterMenu: some View {
        Menu {
            Button("全部类型") { kindFilter = nil }

            Divider()

            ForEach(MemoKind.allCases) { kind in
                Button {
                    kindFilter = kindFilter == kind ? nil : kind
                } label: {
                    Label(kind.title, systemImage: kind.systemImage)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(kindFilter == nil ? DeliveryBarTheme.softText : DeliveryBarTheme.accent)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(kindFilter.map { "只看\($0.title)，点击切换" } ?? "按类型筛选")
    }

    private var memoList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if visibleMemos.isEmpty {
                    emptyListState
                } else {
                    ForEach(visibleMemos) { memo in
                        MemoListRow(
                            memo: memo,
                            isSelected: memo.id == selectedID,
                            onSelect: { select(memo.id) },
                            onTogglePin: { togglePin(memo) },
                            onDelete: { delete(memo) },
                            onRestore: { restore(memo) },
                            onPurge: { purge(memo) }
                        )
                    }
                }
            }
            .padding(DeliveryBarTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyListState: some View {
        VStack(spacing: 6) {
            Image(systemName: showsTrash ? "trash" : "note.text")
                .font(.system(size: 20))
                .foregroundStyle(DeliveryBarTheme.muted)

            Text(emptyListText)
                .font(DeliveryBarTheme.Typography.callout)
                .foregroundStyle(DeliveryBarTheme.softText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var emptyListText: String {
        if showsTrash { return "最近删除是空的" }
        if !searchText.isEmpty || kindFilter != nil { return "没有匹配的备忘" }
        return "还没有备忘\n记点排查过程或流程试试"
    }

    private var listFooter: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach(MemoKind.creatable) { kind in
                    Button {
                        createMemo(kind: kind)
                    } label: {
                        Label(kind.title, systemImage: kind.systemImage)
                    }
                }
            } label: {
                Label("新建", systemImage: "plus")
                    .font(DeliveryBarTheme.Typography.callout)
            } primaryAction: {
                createMemo(kind: .blank)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .help("新建备忘（⌘⇧N 直接新建空白）")

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.16)) {
                    showsTrash.toggle()
                }
                select(nil)
            } label: {
                Label(
                    trashedMemos.isEmpty ? "最近删除" : "最近删除 \(trashedMemos.count)",
                    systemImage: showsTrash ? "trash.fill" : "trash"
                )
                .font(DeliveryBarTheme.Typography.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(showsTrash ? DeliveryBarTheme.accent : DeliveryBarTheme.softText)
            .help("删除的备忘保留 30 天，之后自动清除")
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
        .padding(.vertical, DeliveryBarTheme.Spacing.sm)
    }

    // MARK: Detail pane

    @ViewBuilder
    private var detailPane: some View {
        if let memo = selectedMemo {
            VStack(alignment: .leading, spacing: 0) {
                detailHeader(memo)

                Divider()

                if memo.isDeleted {
                    trashBanner(memo)
                    Divider()
                }

                detailBody(memo)
            }
        } else {
            VStack(spacing: 0) {
                detailHeader(nil)

                Divider()

                ContentUnavailableView {
                    Label("没有选中的备忘", systemImage: "note.text")
                } description: {
                    Text("从左边选一条，或者新建一条。")
                } actions: {
                    HStack(spacing: 8) {
                        ForEach(MemoKind.creatable) { kind in
                            Button {
                                createMemo(kind: kind)
                            } label: {
                                Label(kind.title, systemImage: kind.systemImage)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .labelStyle(.titleAndIcon)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    /// 原来正文上方压着两条工具条（标题栏 + 元信息栏）加两条分割线，正文被顶到很下面。
    /// 现在合成一条：常用的留在栏上，类型 / 截图 / 导出这些低频的进「⋯」。
    private func detailHeader(_ memo: Memo?) -> some View {
        HStack(spacing: 8) {
            if let memo {
                TextField("备忘标题", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(DeliveryBarTheme.Typography.documentTitle)
                    .foregroundStyle(DeliveryBarTheme.ink)
                    .disabled(memo.isDeleted)

                if !memo.isDeleted {
                    tagField
                }

                if let statusText {
                    Text(statusText)
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(DeliveryBarTheme.success)
                        .transition(.opacity)
                } else {
                    Text(DateUtils.relativeUpdateText(for: memo.updatedAt))
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(DeliveryBarTheme.softText)
                }

                if !memo.isDeleted {
                    memoMenu(memo)
                }
            } else {
                Text("备忘")
                    .font(DeliveryBarTheme.Typography.windowTitle)
                    .foregroundStyle(DeliveryBarTheme.ink)

                Spacer()
            }

            ChromeButton(
                systemImage: isWindowPinned ? "pin.fill" : "pin",
                isActive: isWindowPinned,
                help: "窗口保持在最前"
            ) {
                isWindowPinned.toggle()
            }

            ChromeButton(systemImage: "xmark", help: "关闭") {
                flush()
                onClose()
            }
        }
        .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
        .padding(.vertical, DeliveryBarTheme.Spacing.md)
    }

    private var tagField: some View {
        HStack(spacing: 3) {
            Image(systemName: "number")
                .font(.system(size: 9))
                .foregroundStyle(DeliveryBarTheme.muted)

            TextField("标签", text: $draftTag)
                .textFieldStyle(.plain)
                .font(DeliveryBarTheme.Typography.caption)
        }
        .frame(width: 84)
        .help("给备忘打个标签，列表里可以搜到")
    }

    private func memoMenu(_ memo: Memo) -> some View {
        Menu {
            Menu("类型") {
                ForEach(MemoKind.allCases) { kind in
                    Button {
                        setKind(kind, on: memo)
                    } label: {
                        Label(kind.title, systemImage: kind.systemImage)
                    }
                }
            }

            Button(memo.isPinned ? "取消列表置顶" : "置顶到列表顶部") { togglePin(memo) }

            Divider()

            Button("插入剪贴板截图") { insertClipboardImage(into: memo) }
            Button("复制全文") { copyAll(memo) }
            Button("导出 Markdown…") { export(memo) }

            Divider()

            Button("移到最近删除", role: .destructive) { delete(memo) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DeliveryBarTheme.softText)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("类型 / 截图 / 导出 / 删除")
    }

    private func trashBanner(_ memo: Memo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(DeliveryBarTheme.danger)

            Text(trashRemainingText(for: memo))
                .font(DeliveryBarTheme.Typography.callout)
                .foregroundStyle(DeliveryBarTheme.softText)

            Spacer()

            Button("恢复") { restore(memo) }
                .buttonStyle(.borderless)
                .foregroundStyle(DeliveryBarTheme.accent)

            Button("彻底删除", role: .destructive) { purge(memo) }
                .buttonStyle(.borderless)
                .foregroundStyle(DeliveryBarTheme.danger)
        }
        .font(DeliveryBarTheme.Typography.caption)
        .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
        .padding(.vertical, DeliveryBarTheme.Spacing.md)
        .background(DeliveryBarTheme.danger.opacity(0.06))
    }

    private func trashRemainingText(for memo: Memo) -> String {
        guard let deletedAt = memo.deletedAt else { return "已在最近删除中" }
        let elapsed = DateUtils.dayCount(from: deletedAt)
        let remaining = max(MaintenanceService.memoTrashRetentionDays - elapsed, 0)
        return remaining == 0 ? "已在最近删除中，即将清除" : "已在最近删除中，\(remaining) 天后自动清除"
    }

    /// 编辑器现在自己就把 Markdown 渲染出来了（MarkdownSyntaxHighlighter），
    /// 所以「编辑 / 预览」那个切换没有了。只有回收站里的备忘不可编辑，走只读渲染。
    @ViewBuilder
    private func detailBody(_ memo: Memo) -> some View {
        if memo.isDeleted {
            ScrollView {
                Group {
                    if draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("这条备忘还没有正文")
                            .font(DeliveryBarTheme.Typography.callout)
                            .foregroundStyle(DeliveryBarTheme.softText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        MarkdownView(source: draftContent) { reference in
                            image(for: reference, in: memo)
                        }
                    }
                }
                .padding(.horizontal, DeliveryBarTheme.Spacing.xl)
                .padding(.vertical, DeliveryBarTheme.Spacing.xl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                MemoEditorTextView(
                    text: $draftContent,
                    documentID: memo.id,
                    controller: editorController,
                    onInsertImage: { image in attachImage(image, to: memo) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if draftContent.isEmpty {
                    templateHints(for: memo)
                }
            }
        }
    }

    /// 空正文时给个起手式：⌘⇧N 建出来的是空白备忘，这里可以补一个骨架
    private func templateHints(for memo: Memo) -> some View {
        HStack(spacing: 6) {
            Text("用模板开头")
                .font(DeliveryBarTheme.Typography.caption)
                .foregroundStyle(DeliveryBarTheme.softText)

            ForEach(MemoKind.allCases.filter { $0 != .blank }) { kind in
                Button {
                    applyTemplate(kind, to: memo)
                } label: {
                    Label(kind.title, systemImage: kind.systemImage)
                        .font(DeliveryBarTheme.Typography.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, DeliveryBarTheme.Spacing.lg)
        .padding(.vertical, DeliveryBarTheme.Spacing.md)
    }

    // MARK: Selection & drafts

    private func select(_ id: UUID?) {
        guard id != selectedID else { return }
        flush()
        selectedID = id
        loadDraft()
    }

    private func loadDraft() {
        guard let memo = selectedMemo else {
            draftTitle = ""
            draftContent = ""
            draftTag = ""
            return
        }
        draftTitle = memo.title
        draftContent = memo.content
        draftTag = memo.tag
    }

    /// 把草稿写回模型。没有实际变化就不落盘，避免每次防抖都刷新 updatedAt。
    private func flush(announcing: Bool = false) {
        guard let memo = selectedMemo, !memo.isDeleted else { return }

        var changed = false
        if memo.title != draftTitle {
            memo.title = draftTitle
            changed = true
        }
        if memo.content != draftContent {
            memo.content = draftContent
            changed = true
        }
        if memo.tag != draftTag {
            memo.tag = draftTag
            changed = true
        }
        guard changed else { return }

        memo.touch()
        // 正文写回之后再清理，否则刚粘进来的图会被当成没人引用
        memo.pruneUnusedAttachments(in: modelContext)
        modelContext.saveChanges()

        if announcing {
            announce("已保存")
        }
    }

    private func announce(_ message: String) {
        withAnimation(.easeOut(duration: 0.12)) {
            statusText = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard statusText == message else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                statusText = nil
            }
        }
    }

    // MARK: Actions

    private func handleComposeIfNeeded() {
        guard let token = commands.composeToken, token != handledComposeToken else { return }
        handledComposeToken = token
        createMemo(kind: .blank)
    }

    private func createMemo(kind: MemoKind) {
        flush()

        let memo = Memo(content: kind.template, kind: kind)
        modelContext.insert(memo)
        modelContext.saveChanges()

        showsTrash = false
        searchText = ""
        kindFilter = nil
        selectedID = memo.id
        loadDraft()

        // 编辑器是这一帧才挂上去的，等一个渲染回合再抢焦点
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            editorController.focus()
        }
    }

    private func applyTemplate(_ kind: MemoKind, to memo: Memo) {
        setKind(kind, on: memo)
        // 经由编辑器写入，再由 delegate 回流到 draftContent；
        // 直接改 draftContent 编辑器是看不见的（同一条备忘期间不接受外部回写）
        editorController.replaceAll(with: kind.template)
    }

    private func setKind(_ kind: MemoKind, on memo: Memo) {
        guard memo.kind != kind else { return }
        memo.kind = kind
        memo.touch()
        modelContext.saveChanges()
    }

    private func togglePin(_ memo: Memo) {
        memo.isPinned.toggle()
        memo.touch()
        modelContext.saveChanges()
    }

    private func delete(_ memo: Memo) {
        if memo.id == selectedID {
            flush()
        }
        memo.markDeleted()
        modelContext.saveChanges()

        if memo.id == selectedID {
            selectedID = nil
            loadDraft()
        }
    }

    private func restore(_ memo: Memo) {
        memo.restore()
        modelContext.saveChanges()

        if memo.id == selectedID {
            loadDraft()
        }
    }

    private func purge(_ memo: Memo) {
        let wasSelected = memo.id == selectedID
        modelContext.delete(memo)
        modelContext.saveChanges()

        if wasSelected {
            selectedID = nil
            loadDraft()
        }
    }

    // MARK: Images

    private func image(for reference: String, in memo: Memo) -> NSImage? {
        guard
            let id = MemoAttachmentReference.attachmentID(from: reference),
            let attachment = memo.attachment(for: id)
        else { return nil }
        return MemoImageCache.image(for: attachment)
    }

    /// 粘贴/拖拽走到这里：存成附件，返回要写进正文的 Markdown
    private func attachImage(_ image: NSImage, to memo: Memo) -> String? {
        guard let data = MemoImageCodec.pngData(from: image) else { return nil }

        let attachment = MemoAttachment(data: data, memo: memo)
        modelContext.insert(attachment)
        modelContext.saveChanges()

        return "\n\(MemoAttachmentReference.markdown(for: attachment.id))\n"
    }

    private func insertClipboardImage(into memo: Memo) {
        guard let image = MemoPasteboard.forcedImage(from: .general) else {
            announce("剪贴板里没有图片")
            return
        }
        guard let markdown = attachImage(image, to: memo) else {
            announce("图片读取失败")
            return
        }
        editorController.insertAtCursor(markdown)
    }

    // MARK: Export

    private func copyAll(_ memo: Memo) {
        flush()
        Clipboard.copy(memo.markdownDocument)
        announce("已复制全文")
    }

    private func export(_ memo: Memo) {
        flush()

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(MemoExporter.safeFileName(memo.displayTitle)).md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true

        // accessory 应用平时不激活，不激活的话保存面板会藏到别的窗口后面
        NSApp.activate(ignoringOtherApps: true)

        let complete: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            if MemoExporter.write(memo, to: url) {
                announce("已导出")
            } else {
                announce("导出失败")
            }
        }

        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: complete)
        } else {
            panel.begin(completionHandler: complete)
        }
    }
}

// MARK: - List Row

private struct MemoListRow: View {
    let memo: Memo
    let isSelected: Bool
    let onSelect: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onRestore: () -> Void
    let onPurge: () -> Void

    @State private var isHovered = false

    var body: some View {
        // 原来一行塞五组信息、三档字号（10 / 10 / 9pt），人眼分不出层级，只剩「糊」。
        // 压成两行：类型图标 + 标题 / 时间 · 摘要，标签挪到第二行末尾。
        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: memo.kind.systemImage)
                        .font(.system(size: 10))
                        .foregroundStyle(DeliveryBarTheme.muted)
                        .help(memo.kind.title)

                    Text(memo.displayTitle)
                        .font(DeliveryBarTheme.Typography.rowTitle)
                        .foregroundStyle(DeliveryBarTheme.ink)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if memo.isPinned, !memo.isDeleted {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(DeliveryBarTheme.accent)
                    }
                }

                HStack(spacing: 5) {
                    Text("\(DateUtils.relativeUpdateText(for: memo.updatedAt)) · \(memo.preview)")
                        .font(DeliveryBarTheme.Typography.caption)
                        .foregroundStyle(DeliveryBarTheme.softText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !memo.tag.isEmpty {
                        Spacer(minLength: 0)

                        Text(memo.tag)
                            .font(DeliveryBarTheme.Typography.caption)
                            .foregroundStyle(DeliveryBarTheme.softText)
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(DeliveryBarTheme.quietFill, in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            rowAction
                .frame(width: 18)
        }
        .padding(.horizontal, DeliveryBarTheme.Spacing.md)
        .padding(.vertical, DeliveryBarTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous)
                .fill(rowFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous)
                .stroke(isSelected ? DeliveryBarTheme.pillStroke(isSelected: true) : .clear)
        }
        // 整块（含留白和透明区域）都可点。少了它，只有文字本身命中，
        // 点在行的空白处就没反应
        .contentShape(RoundedRectangle(cornerRadius: DeliveryBarTheme.Radius.card, style: .continuous))
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if memo.isDeleted {
                Button("恢复", action: onRestore)
                Button("彻底删除", role: .destructive, action: onPurge)
            } else {
                Button(memo.isPinned ? "取消置顶" : "置顶", action: onTogglePin)
                Button("复制全文") { Clipboard.copy(memo.markdownDocument) }
                Divider()
                Button("移到最近删除", role: .destructive, action: onDelete)
            }
        }
    }

    /// 悬停才出现，跟待办/日志行的删除按钮一个路子。
    /// 已删除的行给「恢复」——彻底删除是不可逆的，只留在详情横幅和右键菜单里。
    @ViewBuilder
    private var rowAction: some View {
        Button {
            if memo.isDeleted {
                onRestore()
            } else {
                onDelete()
            }
        } label: {
            Image(systemName: memo.isDeleted ? "arrow.uturn.backward" : "trash")
                .font(.system(size: 11))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(DeliveryBarTheme.softText)
        .opacity(isHovered ? 1 : 0)
        .allowsHitTesting(isHovered)
        .help(memo.isDeleted ? "恢复这条备忘" : "移到最近删除（30 天内可恢复）")
    }

    private var rowFill: Color {
        if isSelected { return DeliveryBarTheme.selectedBackground }
        return Color.primary.opacity(isHovered ? 0.05 : 0)
    }
}

// MARK: - Image cache

/// 每次重绘都从 Data 解一遍大截图会明显掉帧，解出来的 NSImage 按附件 id 缓存
enum MemoImageCache {
    private static let cache = NSCache<NSUUID, NSImage>()

    static func image(for attachment: MemoAttachment) -> NSImage? {
        let key = attachment.id as NSUUID
        if let cached = cache.object(forKey: key) { return cached }

        guard let image = NSImage(data: attachment.data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

// MARK: - Export

enum MemoExporter {
    /// 导出 .md；正文里引用的截图一起落到同名 `.assets` 目录，并把引用改写成相对路径，
    /// 这样导出的文件在任何 Markdown 编辑器里都能直接看图。
    static func write(_ memo: Memo, to url: URL) -> Bool {
        var document = memo.markdownDocument
        let referenced = MemoAttachmentReference.referencedIDs(in: memo.content)

        if !referenced.isEmpty {
            let assetsName = url.deletingPathExtension().lastPathComponent + ".assets"
            let assetsURL = url.deletingLastPathComponent().appendingPathComponent(assetsName, isDirectory: true)
            try? FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)

            for id in referenced {
                guard let attachment = memo.attachment(for: id) else { continue }
                let fileName = "\(id.uuidString).png"
                try? attachment.data.write(to: assetsURL.appendingPathComponent(fileName))
                document = document.replacingOccurrences(
                    of: "\(MemoAttachmentReference.scheme)://\(id.uuidString)",
                    with: "\(assetsName)/\(fileName)"
                )
            }
        }

        do {
            try document.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    static func safeFileName(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = title
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "备忘" : String(cleaned.prefix(60))
    }
}
