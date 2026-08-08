//
//  FloatingPanelController.swift
//  DeliveryBar
//

import AppKit
import SwiftData
import SwiftUI

final class FloatingPanelController: NSObject, NSWindowDelegate {
    private enum Layout {
        static let mainDefaultSize = CGSize(width: 460, height: 540)
        // 改左右分栏之后要更宽才够两栏并排看
        static let jsonSize = CGSize(width: 920, height: 640)
        static let jsonMinSize = CGSize(width: 720, height: 460)
        static let jsonFrameAutosaveName = "DeliveryBarJSONPanel"
        static let memoSize = CGSize(width: 880, height: 560)
        static let memoMinSize = CGSize(width: 680, height: 420)
        static let memoFrameAutosaveName = "DeliveryBarMemoPanel"
        static let statusItemPadding: CGFloat = 8
    }

    private let modelContainer: ModelContainer
    private let memoCommands = MemoWindowCommands()
    private var outsideClickMonitor: Any?
    private var appActivationObserver: NSObjectProtocol?
    private weak var mainAnchorButton: NSStatusBarButton?
    private var mainPanel: DeliveryFloatingPanel?
    private var jsonPanel: DeliveryFloatingPanel?
    private var memoPanel: DeliveryFloatingPanel?
    private var mainHostingController: NSHostingController<AnyView>?
    private var jsonHostingController: NSHostingController<AnyView>?
    private var memoHostingController: NSHostingController<AnyView>?
    private var isJSONPinned = false
    private var isMemoPinned = false

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        installDismissObservers()
    }

    deinit {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
        }
    }

    func toggleMainPanel(relativeTo button: NSStatusBarButton?) {
        guard let mainPanel, mainPanel.isVisible else {
            showMainPanel(relativeTo: button)
            return
        }

        mainPanel.orderOut(nil)
    }

    func showMainPanel(relativeTo button: NSStatusBarButton?) {
        mainAnchorButton = button
        // 已置顶的 JSON 面板不随主面板打开而收起
        if !isJSONPinned {
            hideJSONFormatter()
        }

        let panel = mainPanel ?? makeMainPanel()
        mainPanel = panel

        panel.layoutIfNeeded()
        positionMainPanel(panel, relativeTo: button)
        show(panel)
        // 首次显示时内容尺寸可能在 show 过程中才落定，补一次定位避免面板脱离状态栏
        positionMainPanel(panel, relativeTo: button)
    }

    func toggleJSONFormatter() {
        guard let jsonPanel, jsonPanel.isVisible else {
            showJSONFormatter()
            return
        }

        jsonPanel.orderOut(nil)
    }

    func showJSONFormatter() {
        mainPanel?.orderOut(nil)

        let panel = jsonPanel ?? makeJSONPanel()
        jsonPanel = panel

        // 窗口可自由缩放，位置和尺寸由用户决定并自动保存，重开时保持不变
        show(panel)
    }

    func hideJSONFormatter() {
        jsonPanel?.orderOut(nil)
    }

    func setJSONPinned(_ isPinned: Bool) {
        isJSONPinned = isPinned
        jsonPanel?.collectionBehavior = isPinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            : [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    /// 打开备忘窗口。compose 为 true 时顺带请求新建一条空白备忘（全局快捷键入口）。
    func showMemoWindow(compose: Bool = false) {
        mainPanel?.orderOut(nil)

        let panel = memoPanel ?? makeMemoPanel()
        memoPanel = panel

        show(panel)

        if compose {
            memoCommands.requestCompose()
        }
    }

    func hideMemoWindow() {
        memoPanel?.orderOut(nil)
    }

    func setMemoPinned(_ isPinned: Bool) {
        isMemoPinned = isPinned
        memoPanel?.level = isPinned ? .popUpMenu : .floating
        memoPanel?.collectionBehavior = isPinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            : [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === jsonPanel {
            setJSONPinned(false)
        }
        if notification.object as? NSWindow === memoPanel {
            setMemoPinned(false)
        }
    }

    private func makeMainPanel() -> DeliveryFloatingPanel {
        let panel = makePanel(size: Layout.mainDefaultSize, level: .statusBar)
        // 先持有引用再挂内容：SwiftUI onAppear 会立刻上报首选尺寸，此时 resizeMainPanel 需要能拿到 panel
        mainPanel = panel
        panel.contentView = makeContentView(hosting: makeMainContent(), material: .popover)
        return panel
    }

    private func makeJSONPanel() -> DeliveryFloatingPanel {
        let panel = makePanel(size: Layout.jsonSize, level: .floating, isResizable: true)
        panel.title = "JSON 格式化"
        panel.contentMinSize = Layout.jsonMinSize
        panel.contentView = makeContentView(hosting: makeJSONContent(), material: .underWindowBackground)

        panel.setFrameAutosaveName(Layout.jsonFrameAutosaveName)
        // 没有存过尺寸就是第一次打开，居中；否则沿用上次拉好的窗口
        if !panel.setFrameUsingName(Layout.jsonFrameAutosaveName) {
            positionCentered(panel)
        }
        return panel
    }

    private func makeMemoPanel() -> DeliveryFloatingPanel {
        let panel = makePanel(size: Layout.memoSize, level: .floating, isResizable: true)
        panel.title = "备忘"
        panel.contentMinSize = Layout.memoMinSize
        panel.contentView = makeContentView(hosting: makeMemoContent(), material: .underWindowBackground)

        panel.setFrameAutosaveName(Layout.memoFrameAutosaveName)
        if !panel.setFrameUsingName(Layout.memoFrameAutosaveName) {
            positionCentered(panel)
        }
        return panel
    }

    private func makePanel(size: CGSize, level: NSWindow.Level, isResizable: Bool = false) -> DeliveryFloatingPanel {
        // .nonactivatingPanel + 高于 .normal 的层级：面板可以直接盖在其他 App 的全屏窗口上，
        // 成为 key window 接收键盘输入，而不激活本应用（激活会把系统切出全屏 Space）
        var styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        if isResizable {
            styleMask.insert(.resizable)
        }

        let panel = DeliveryFloatingPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = level
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = false
        return panel
    }

    private func makeMainContent() -> NSHostingController<AnyView> {
        let hostingController = NSHostingController(rootView: mainRootView())
        mainHostingController = hostingController
        return hostingController
    }

    private func makeJSONContent() -> NSHostingController<AnyView> {
        let hostingController = NSHostingController(rootView: jsonRootView())
        jsonHostingController = hostingController
        return hostingController
    }

    private func makeMemoContent() -> NSHostingController<AnyView> {
        let hostingController = NSHostingController(rootView: memoRootView())
        memoHostingController = hostingController
        return hostingController
    }

    private func makeContentView(
        hosting hostingController: NSHostingController<AnyView>,
        material: NSVisualEffectView.Material
    ) -> NSView {
        let effectView = NSVisualEffectView()
        effectView.material = material
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.maskImage = cornerMask(radius: DeliveryBarTheme.Radius.panel)

        let hostingView = hostingController.view
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        effectView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])

        return effectView
    }

    private func cornerMask(radius: CGFloat) -> NSImage {
        let size = CGSize(width: radius * 2 + 1, height: radius * 2 + 1)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private func mainRootView() -> AnyView {
        AnyView(
            MenuBarView(
                onOpenJSONFormatter: { [weak self] in
                    self?.mainPanel?.orderOut(nil)
                    self?.showJSONFormatter()
                },
                onOpenMemo: { [weak self] in
                    self?.showMemoWindow()
                },
                onPreferredSizeChange: { [weak self] size in
                    self?.resizeMainPanel(to: size)
                }
            )
            .modelContainer(modelContainer)
        )
    }

    private func memoRootView() -> AnyView {
        AnyView(
            MemoWindowView(
                commands: memoCommands,
                onPinnedChange: { [weak self] isPinned in
                    self?.setMemoPinned(isPinned)
                },
                onClose: { [weak self] in
                    self?.hideMemoWindow()
                }
            )
            .modelContainer(modelContainer)
        )
    }

    private func jsonRootView() -> AnyView {
        AnyView(
            JSONFormatterView(
                onPinnedChange: { [weak self] isPinned in
                    self?.setJSONPinned(isPinned)
                },
                onClose: { [weak self] in
                    self?.hideJSONFormatter()
                }
            )
            .modelContainer(modelContainer)
        )
    }

    private func resizeMainPanel(to size: CGSize) {
        guard let panel = mainPanel else { return }
        let clampedSize = CGSize(width: size.width, height: max(size.height, 300))
        panel.setContentSize(clampedSize)

        if panel.isVisible {
            positionMainPanel(panel, relativeTo: mainAnchorButton)
        }
        panel.invalidateShadow()
    }

    // 本应用始终保持未激活，不能靠 didResignActive 收面板；
    // 改为监听「点到其他 App / 焦点切到其他 App」两类信号
    private func installDismissObservers() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.hideTransientPanels()
        }

        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            else { return }
            self?.hideTransientPanels()
        }
    }

    /// 备忘窗口刻意不在这里：那是个写长文的窗口，切去别的 App 复制一段报错回来
    /// 还能接着写，只能由用户显式关闭。
    private func hideTransientPanels() {
        mainPanel?.orderOut(nil)

        if !isJSONPinned {
            jsonPanel?.orderOut(nil)
        }
    }

    private func show(_ panel: NSPanel) {
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func positionMainPanel(_ panel: NSPanel, relativeTo button: NSStatusBarButton?) {
        guard
            let button,
            let buttonWindow = button.window,
            let screen = buttonWindow.screen ?? NSScreen.main
        else {
            panel.center()
            return
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
        let visibleFrame = screen.visibleFrame
        var frame = panel.frame

        frame.origin.x = buttonFrameOnScreen.midX - frame.width / 2
        frame.origin.y = buttonFrameOnScreen.minY - frame.height - Layout.statusItemPadding
        frame.origin.x = min(max(frame.origin.x, visibleFrame.minX + 8), visibleFrame.maxX - frame.width - 8)
        frame.origin.y = max(frame.origin.y, visibleFrame.minY + 8)

        panel.setFrame(frame, display: true)
    }

    private func positionCentered(_ panel: NSPanel) {
        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(NSEvent.mouseLocation)
        } ?? NSScreen.main

        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }

        var frame = panel.frame
        frame.origin.x = visibleFrame.midX - frame.width / 2
        frame.origin.y = visibleFrame.midY - frame.height / 2
        panel.setFrame(frame, display: true)
    }
}

final class DeliveryFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // 应用未激活时主菜单不参与快捷键分发，编辑类快捷键在窗口层手动路由到 first responder
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }

        switch (modifiers, key) {
        case ([.command], "x"):
            return sendEditAction(#selector(NSText.cut(_:)))
        case ([.command], "c"):
            return sendEditAction(#selector(NSText.copy(_:)))
        case ([.command], "v"):
            return sendEditAction(#selector(NSText.paste(_:)))
        case ([.command], "a"):
            return sendEditAction(#selector(NSText.selectAll(_:)))
        case ([.command], "z"):
            return sendEditAction(Selector(("undo:")))
        case ([.command, .shift], "z"):
            return sendEditAction(Selector(("redo:")))
        case ([.command], "w"):
            orderOut(nil)
            return true
        case ([.command], "q"):
            NSApp.terminate(nil)
            return true
        default:
            return false
        }
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    private func sendEditAction(_ action: Selector) -> Bool {
        NSApp.sendAction(action, to: nil, from: self)
    }
}
