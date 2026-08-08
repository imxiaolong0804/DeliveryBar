//
//  HotKeyService.swift
//  DeliveryBar
//

import Carbon.HIToolbox
import Foundation

final class HotKeyService {
    /// 主面板不再占全局快捷键——它就在菜单栏上，点一下就开，
    /// 没必要为此长期霸占一个系统级组合键。
    enum Shortcut: CaseIterable {
        case jsonFormatter
        case newMemo

        var id: UInt32 {
            switch self {
            case .jsonFormatter:
                2
            case .newMemo:
                3
            }
        }

        var displayName: String {
            switch self {
            case .jsonFormatter:
                "⌘⇧J"
            case .newMemo:
                "⌘⇧N"
            }
        }

        var keyCode: UInt32 {
            switch self {
            case .jsonFormatter:
                UInt32(kVK_ANSI_J)
            case .newMemo:
                UInt32(kVK_ANSI_N)
            }
        }

        var modifierFlags: UInt32 {
            UInt32(cmdKey | shiftKey)
        }

        var registeredKey: String {
            switch self {
            case .jsonFormatter:
                "jsonHotKeyRegistered"
            case .newMemo:
                "memoHotKeyRegistered"
            }
        }

        var statusKey: String {
            switch self {
            case .jsonFormatter:
                "jsonHotKeyStatusText"
            case .newMemo:
                "memoHotKeyStatusText"
            }
        }
    }

    private static let signature = HotKeyService.fourCharCode("DBar")

    private var registeredHotKeys: [UInt32: EventHotKeyRef] = [:]
    private var callbacks: [UInt32: () -> Void] = [:]
    private var eventHandlerRef: EventHandlerRef?

    init() {
        installEventHandler()
    }

    deinit {
        unregisterAll()
    }

    func register(_ shortcut: Shortcut, action: @escaping () -> Void) {
        callbacks[shortcut.id] = action

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: shortcut.id)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            registeredHotKeys[shortcut.id] = hotKeyRef
            updateStatus(for: shortcut, statusText: "\(shortcut.displayName) 已启用", isRegistered: true)
        } else {
            updateStatus(for: shortcut, statusText: "\(shortcut.displayName) 注册失败（\(status)）", isRegistered: false)
        }
    }

    func unregisterAll() {
        registeredHotKeys.values.forEach { UnregisterEventHotKey($0) }
        registeredHotKeys.removeAll()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func handleHotKey(id: UInt32) {
        callbacks[id]?()
    }

    private func updateStatus(for shortcut: Shortcut, statusText: String, isRegistered: Bool) {
        UserDefaults.standard.set(isRegistered, forKey: shortcut.registeredKey)
        UserDefaults.standard.set(statusText, forKey: shortcut.statusKey)
    }

    private static let eventHandler: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return noErr }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else { return status }

        let service = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()
        DispatchQueue.main.async {
            service.handleHotKey(id: hotKeyID.id)
        }

        return noErr
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}
