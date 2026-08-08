//
//  StatusBarController.swift
//  DeliveryBar
//

import AppKit
import SwiftData

final class StatusBarController: NSObject {
    /// 兜底轮询间隔。跨天、到期阈值这类「时间到了」的变化没有保存事件可依赖，
    /// 但都是天级别的，不需要每分钟醒一次。
    private static let fallbackRefreshInterval: TimeInterval = 300

    private let statusItem: NSStatusItem
    private let panelController: FloatingPanelController
    private let modelContainer: ModelContainer
    private var badgeTimer: Timer?
    private var saveObserver: NSObjectProtocol?

    init(panelController: FloatingPanelController, modelContainer: ModelContainer) {
        self.panelController = panelController
        self.modelContainer = modelContainer
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusItem()
        refreshBadge()

        // 面板里改完需求立刻反映到角标，不用等下一次轮询
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshBadge()
        }

        badgeTimer = Timer.scheduledTimer(
            withTimeInterval: Self.fallbackRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshBadge()
        }
    }

    deinit {
        badgeTimer?.invalidate()
        if let saveObserver {
            NotificationCenter.default.removeObserver(saveObserver)
        }
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
        button.toolTip = DeliveryBarTheme.appName
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
