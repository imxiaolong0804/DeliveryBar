//
//  DeliveryBarApp.swift
//  DeliveryBar
//
//  Created by didi on 2026/6/28.
//

import SwiftData
import AppKit

@main
enum DeliveryBarApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = DeliveryBarAppDelegate()
        DeliveryBarAppDelegateStorage.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.mainMenu = makeMainMenu()
        app.run()
    }

    // Accessory 应用不显示菜单栏，但 ⌘C/⌘V 等编辑快捷键依赖 mainMenu 分发到 first responder
    private static func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "退出 \(DeliveryBarTheme.appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }
}

private enum DeliveryBarAppDelegateStorage {
    static var delegate: DeliveryBarAppDelegate?
}

final class DeliveryBarAppDelegate: NSObject, NSApplicationDelegate {
    private var modelContainer: ModelContainer?
    private var panelController: FloatingPanelController?
    private var statusBarController: StatusBarController?
    private var hotKeyService: HotKeyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let container = Self.makeModelContainer()
        modelContainer = container

        performLaunchMaintenance(using: container)

        let panelController = FloatingPanelController(modelContainer: container)
        let statusBarController = StatusBarController(panelController: panelController, modelContainer: container)
        let hotKeyService = HotKeyService()

        hotKeyService.register(.mainBar) { [weak statusBarController] in
            statusBarController?.toggleMainPanel()
        }
        hotKeyService.register(.jsonFormatter) { [weak panelController] in
            panelController?.showJSONFormatter()
        }

        self.panelController = panelController
        self.statusBarController = statusBarController
        self.hotKeyService = hotKeyService
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyService?.unregisterAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            Requirement.self,
            TemporaryTask.self,
            PersonProfile.self,
            QuickEntry.self,
            JSONFormatHistory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private func performLaunchMaintenance(using container: ModelContainer) {
        let context = ModelContext(container)

        do {
            let requirements = try context.fetch(FetchDescriptor<Requirement>())
            let legacyRequirements = requirements.filter { $0.status == .developedNotDelivered }
            legacyRequirements.forEach {
                $0.statusRaw = RequirementStatus.waitingAcceptance.rawValue
            }

            let temporaryTasks = try context.fetch(FetchDescriptor<TemporaryTask>())
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let cutoffDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            temporaryTasks
                .filter { task in
                    calendar.startOfDay(for: task.taskDate) < cutoffDate
                        && (task.category == .log || task.isCompleted)
                }
                .forEach { context.delete($0) }

            if context.hasChanges {
                try context.save()
            }
        } catch {
            assertionFailure("Failed to perform launch maintenance: \(error)")
        }
    }
}
