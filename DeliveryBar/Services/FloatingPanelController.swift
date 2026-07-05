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
        static let jsonSize = CGSize(width: 820, height: 620)
        static let statusItemPadding: CGFloat = 8
    }

    private let modelContainer: ModelContainer
    private var resignActiveObserver: NSObjectProtocol?
    private weak var mainAnchorButton: NSStatusBarButton?
    private var mainPanel: DeliveryFloatingPanel?
    private var jsonPanel: DeliveryFloatingPanel?
    private var mainHostingController: NSHostingController<AnyView>?
    private var jsonHostingController: NSHostingController<AnyView>?
    private var isJSONPinned = false

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        super.init()
        installActivationObserver()
    }

    deinit {
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
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
        hideJSONFormatter()

        let panel = mainPanel ?? makeMainPanel()
        mainPanel = panel

        positionMainPanel(panel, relativeTo: button)
        show(panel)
    }

    func showJSONFormatter() {
        mainPanel?.orderOut(nil)

        let panel = jsonPanel ?? makeJSONPanel()
        jsonPanel = panel

        rebuildJSONContent()
        panel.setContentSize(Layout.jsonSize)
        positionJSONPanel(panel)
        show(panel)
    }

    func hideJSONFormatter() {
        jsonPanel?.orderOut(nil)
    }

    func setJSONPinned(_ isPinned: Bool) {
        guard let jsonPanel else { return }
        isJSONPinned = isPinned
        jsonPanel.hidesOnDeactivate = false
        jsonPanel.level = isPinned ? .floating : .normal
        jsonPanel.collectionBehavior = isPinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            : [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === jsonPanel {
            setJSONPinned(false)
        }
    }

    private func makeMainPanel() -> DeliveryFloatingPanel {
        let panel = makePanel(size: Layout.mainDefaultSize)
        panel.contentViewController = makeMainContent()
        return panel
    }

    private func makeJSONPanel() -> DeliveryFloatingPanel {
        let panel = makePanel(size: Layout.jsonSize)
        panel.title = "JSON 格式化"
        panel.contentViewController = makeJSONContent()
        return panel
    }

    private func makePanel(size: CGSize) -> DeliveryFloatingPanel {
        let panel = DeliveryFloatingPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
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

    private func rebuildJSONContent() {
        if let jsonHostingController {
            jsonHostingController.rootView = jsonRootView()
        } else if let jsonPanel {
            jsonPanel.contentViewController = makeJSONContent()
        }
        setJSONPinned(false)
    }

    private func mainRootView() -> AnyView {
        AnyView(
            MenuBarView(
                onOpenJSONFormatter: { [weak self] in
                    self?.mainPanel?.orderOut(nil)
                    self?.showJSONFormatter()
                },
                onPreferredSizeChange: { [weak self] size in
                    self?.resizeMainPanel(to: size)
                }
            )
            .modelContainer(modelContainer)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
    }

    private func resizeMainPanel(to size: CGSize) {
        guard let panel = mainPanel else { return }
        let clampedSize = CGSize(width: size.width, height: max(size.height, 300))
        panel.setContentSize(clampedSize)

        if panel.isVisible {
            positionMainPanel(panel, relativeTo: mainAnchorButton)
        }
    }

    private func installActivationObserver() {
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            self?.hideTransientPanels()
        }
    }

    private func hideTransientPanels() {
        mainPanel?.orderOut(nil)

        if !isJSONPinned {
            jsonPanel?.orderOut(nil)
        }
    }

    private func show(_ panel: NSPanel) {
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
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

    private func positionJSONPanel(_ panel: NSPanel) {
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
}
