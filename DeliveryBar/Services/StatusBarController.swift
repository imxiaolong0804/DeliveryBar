//
//  StatusBarController.swift
//  DeliveryBar
//

import AppKit
import SwiftData

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let panelController: FloatingPanelController
    private let modelContainer: ModelContainer
    private var badgeTimer: Timer?

    init(panelController: FloatingPanelController, modelContainer: ModelContainer) {
        self.panelController = panelController
        self.modelContainer = modelContainer
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
        refreshBadge()
        badgeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshBadge()
        }
    }

    deinit {
        badgeTimer?.invalidate()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func toggleMainPanel() {
        panelController.toggleMainPanel(relativeTo: statusItem.button)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        statusItem.isVisible = true
        if let image = Self.makeStatusImage() {
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
            statusItem.length = NSStatusItem.squareLength
        } else {
            button.image = nil
            button.title = "DB"
            statusItem.length = 42
        }
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "\(DeliveryBarTheme.appName)（⌘⇧D）"
    }

    private static func makeStatusImage() -> NSImage? {
        let symbols = [
            "checklist.checked",
            "checklist",
            "checkmark.circle",
        ]

        for symbol in symbols {
            if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: DeliveryBarTheme.appName) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                return image
            }
        }

        return nil
    }

    @objc private func statusItemClicked() {
        toggleMainPanel()
    }

    private func refreshBadge() {
        guard let button = statusItem.button else { return }

        let context = ModelContext(modelContainer)
        let remindersEnabled = UserDefaults.standard.object(forKey: "remindersEnabled") as? Bool ?? true
        let count: Int

        do {
            let requirements = try context.fetch(FetchDescriptor<Requirement>())
            count = requirements.filter {
                ReminderService.attentionReason(for: $0, remindersEnabled: remindersEnabled) != nil
            }.count
        } catch {
            count = 0
        }

        if count > 0 {
            button.imagePosition = button.image == nil ? .noImage : .imageLeft
            button.title = " \(count)"
            statusItem.length = button.image == nil ? 42 : 48
        } else if button.image == nil {
            button.title = "DB"
            statusItem.length = 42
        } else {
            button.imagePosition = .imageOnly
            button.title = ""
            statusItem.length = NSStatusItem.squareLength
        }
        button.setAccessibilityLabel(
            count > 0
                ? "\(DeliveryBarTheme.appName), \(count) 个需求需要关注"
                : DeliveryBarTheme.appName
        )
    }
}
