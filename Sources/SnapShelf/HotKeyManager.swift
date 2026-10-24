import AppKit
import Carbon

enum CaptureShortcut: String, CaseIterable {
    case commandA, commandShiftA, commandOptionA, controlOptionA
    var title: String {
        switch self {
        case .commandA: return "⌘A（Command+A）"
        case .commandShiftA: return "⇧⌘A（Command+Shift+A）"
        case .commandOptionA: return "⌥⌘A（Command+Option+A）"
        case .controlOptionA: return "⌃⌥A（Control+Option+A）"
        }
    }
    var modifiers: UInt32 {
        switch self {
        case .commandA: return UInt32(cmdKey)
        case .commandShiftA: return UInt32(cmdKey | shiftKey)
        case .commandOptionA: return UInt32(cmdKey | optionKey)
        case .controlOptionA: return UInt32(controlKey | optionKey)
        }
    }
}

final class HotKeyManager {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?

    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { manager.onPress?() }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    @discardableResult
    func register(_ shortcut: CaptureShortcut) -> Bool {
        var newHotKey: EventHotKeyRef?
        let id = EventHotKeyID(signature: 0x534E4150, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_A), shortcut.modifiers, id,
                                        GetApplicationEventTarget(), 0, &newHotKey)
        guard result == noErr else { return false }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = newHotKey
        return true
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
