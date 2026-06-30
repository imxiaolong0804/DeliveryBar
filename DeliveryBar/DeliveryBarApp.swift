//
//  DeliveryBarApp.swift
//  DeliveryBar
//
//  Created by didi on 2026/6/28.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct DeliveryBarApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Requirement.self,
            TemporaryTask.self,
            PersonProfile.self,
            QuickEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .modelContainer(sharedModelContainer)
                .background(InputMethodPanelFix())
        } label: {
            MenuBarLabelView()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
    }
}

/// MenuBarExtra(.window) 的 NSPanel 在全屏 Space 中容易保持非激活状态，
/// 中文输入法候选窗会因此无法跟随当前输入框显示。
private struct InputMethodPanelFix: NSViewRepresentable {
    func makeNSView(context: Context) -> PanelFixView {
        PanelFixView()
    }

    func updateNSView(_ nsView: PanelFixView, context: Context) {
        nsView.configurePanelForTextInput()
    }
}

private class PanelFixView: NSView {
    private var textFieldObserver: NSObjectProtocol?
    private var textViewObserver: NSObjectProtocol?

    deinit {
        removeEditingObservers()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installEditingObservers()
        configurePanelForTextInput()

        DispatchQueue.main.async { [weak self] in
            self?.configurePanelForTextInput(activate: false)
        }
    }

    func configurePanelForTextInput(activate: Bool = false) {
        guard let panel = window as? NSPanel else { return }
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = panel.collectionBehavior.union([.canJoinAllSpaces, .fullScreenAuxiliary])

        if activate {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else if panel.isVisible {
            panel.makeKey()
        }
    }

    private func installEditingObservers() {
        removeEditingObservers()

        textFieldObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.activatePanelIfNeeded(for: notification)
        }

        textViewObserver = NotificationCenter.default.addObserver(
            forName: NSText.didBeginEditingNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.activatePanelIfNeeded(for: notification)
        }
    }

    private func removeEditingObservers() {
        if let textFieldObserver {
            NotificationCenter.default.removeObserver(textFieldObserver)
        }
        if let textViewObserver {
            NotificationCenter.default.removeObserver(textViewObserver)
        }
        textFieldObserver = nil
        textViewObserver = nil
    }

    private func activatePanelIfNeeded(for notification: Notification) {
        guard notificationWindow(for: notification) === window else { return }
        configurePanelForTextInput(activate: true)
    }

    private func notificationWindow(for notification: Notification) -> NSWindow? {
        if let view = notification.object as? NSView {
            return view.window
        }
        return nil
    }
}
