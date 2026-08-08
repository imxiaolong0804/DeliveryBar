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

        MaintenanceService.run(in: ModelContext(container))

        let panelController = FloatingPanelController(modelContainer: container)
        let statusBarController = StatusBarController(panelController: panelController, modelContainer: container)
        let hotKeyService = HotKeyService()

        hotKeyService.register(.jsonFormatter) { [weak panelController] in
            panelController?.toggleJSONFormatter()
        }
        hotKeyService.register(.newMemo) { [weak panelController] in
            panelController?.showMemoWindow(compose: true)
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
            Memo.self,
            MemoAttachment.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
            return container
        }

        // 打不开一般意味着模型变更无法自动迁移。把旧库改名留档后用空库继续启动，
        // 数据还能从备份里捞，总好过 app 永远起不来。
        archiveStore(at: modelConfiguration.url)

        if let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
            return container
        }

        // 连磁盘都写不了，退到内存库：本次会话不落盘，但工具仍然可用
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memoryConfiguration])
    }

    private static func archiveStore(at storeURL: URL) {
        let fileManager = FileManager.default
        let suffix = ".backup-\(Int(Date().timeIntervalSince1970))"

        // SQLite 的 -shm / -wal 边车文件要一起挪走，否则新库会读到旧的预写日志
        for sidecar in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: storeURL.path + sidecar)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try? fileManager.moveItem(at: source, to: URL(fileURLWithPath: storeURL.path + suffix + sidecar))
        }
    }
}
