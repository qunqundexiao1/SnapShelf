import AppKit

@main
enum AppMain {
    static func main() {
        let app = NSApplication.shared
        let identifier = Bundle.main.bundleIdentifier ?? "com.local.snapshelf"
        if NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            return
        }
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var store: ClipboardStore!
    private var capture: CaptureCoordinator!
    private let hotKey = HotKeyManager()
    private var shortcut = CaptureShortcut(rawValue: UserDefaults.standard.string(forKey: "captureShortcut") ?? "") ?? .commandA
    private var shortcutActive = false
    private let statusLine = NSMenuItem(title: "等待截图", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            store = try ClipboardStore()
            try store.removeOrphans()
        } catch {
            showError("无法准备临时存储：\(error.localizedDescription)")
            NSApp.terminate(nil)
            return
        }
        capture = CaptureCoordinator(store: store)
        store.onChange = { [weak self] in self?.refreshStatus() }
        store.onCleanupError = { [weak self] error in
            self?.showError("临时文件清理失败：\(error.localizedDescription)\n可通过菜单中的「打开临时目录」检查文件。")
        }
        capture.onStateChange = { [weak self] in self?.refreshStatus() }
        capture.onError = { [weak self] message in self?.showError(message) }
        store.startMonitoring()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "SnapShelf 临时截图")
        hotKey.onPress = { [weak self] in self?.capture.capture() }
        shortcutActive = hotKey.register(shortcut)
        rebuildMenu()
        refreshStatus()
        if !shortcutActive { showError("快捷键 \(shortcut.title) 已被其他程序占用。请从菜单栏图标的「截图快捷键」中选择另一个组合。") }
        if !UserDefaults.standard.bool(forKey: "hasShownWelcome") {
            UserDefaults.standard.set(true, forKey: "hasShownWelcome")
            showHelp(nil)
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "SnapShelf · 临时截图", action: nil, keyEquivalent: ""))
        menu.addItem(statusLine)
        menu.addItem(.separator())
        add("框选截图", action: #selector(takeScreenshot), to: menu)
        let shortcuts = NSMenu()
        for choice in CaptureShortcut.allCases {
            let item = NSMenuItem(title: choice.title, action: #selector(changeShortcut(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.rawValue
            item.state = choice == shortcut && shortcutActive ? .on : .off
            shortcuts.addItem(item)
        }
        let shortcutItem = NSMenuItem(title: "截图快捷键", action: nil, keyEquivalent: "")
        shortcutItem.submenu = shortcuts
        menu.addItem(shortcutItem)
        add("清除当前临时截图", action: #selector(clearScreenshot), to: menu)
        add("打开临时目录", action: #selector(openCache), to: menu)
        menu.addItem(.separator())
        add("屏幕录制权限设置…", action: #selector(openPermissions), to: menu)
        add("使用说明…", action: #selector(showHelp(_:)), to: menu)
        add("退出 SnapShelf", action: #selector(quit), to: menu)
        statusItem.menu = menu
    }

    private func add(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private func refreshStatus() {
        guard statusItem != nil else { return }
        statusLine.title = capture.isCapturing ? "正在框选 · Esc 取消" : store.currentFile == nil ? "等待截图 · 临时目录为空" : "截图已就绪 · 可按 ⌘V 粘贴"
        statusItem.button?.toolTip = "SnapShelf：\(statusLine.title)\n截图快捷键：\(shortcutActive ? shortcut.title : "未启用")"
        statusItem.button?.image = NSImage(systemSymbolName: store.currentFile == nil ? "viewfinder" : "photo.on.rectangle", accessibilityDescription: "SnapShelf 临时截图")
    }

    @objc private func takeScreenshot() {
        // Wait for the menu to close before the native selection overlay starts.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in self?.capture.capture() }
    }
    @objc private func changeShortcut(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let choice = CaptureShortcut(rawValue: raw), choice != shortcut || !shortcutActive else { return }
        guard hotKey.register(choice) else { showError("此快捷键已被占用，请选择其他组合。"); return }
        shortcut = choice
        shortcutActive = true
        UserDefaults.standard.set(choice.rawValue, forKey: "captureShortcut")
        rebuildMenu()
        refreshStatus()
    }
    @objc private func clearScreenshot() { store.clearCurrent() }
    @objc private func openCache() { NSWorkspace.shared.open(store.directory) }
    @objc private func openPermissions() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func showHelp(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "SnapShelf · 截图即粘贴"
        alert.informativeText = "1. 按 \(shortcut.title) 后拖动选择区域，按 Esc 取消；选择时按空格可切换窗口截图。\n\n2. 按 ⌘V 粘贴到支持图片或附件的聊天框、文档，或 Finder 文件夹。纯文字输入框无法接收图片，具体行为由目标应用决定。\n\n3. 截图临时保存在本机缓存。复制其他文字、图片或文件后，通常在 0.2 秒内自动删除临时截图。已粘贴保存的副本会保留。\n\n默认 ⌘A 会占用「全选」，可在菜单中更改。退出会清除当前临时截图；意外退出遗留的文件会在下次启动时清理。\n\n首次截图需在系统设置中授予屏幕录制权限。"
        alert.addButton(withTitle: "开始使用")
        alert.runModal()
    }
    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "SnapShelf"
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
    func applicationWillTerminate(_ notification: Notification) {
        capture?.shutdown()
        store?.shutdown()
    }
}
