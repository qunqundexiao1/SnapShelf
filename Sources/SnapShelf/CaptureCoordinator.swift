import AppKit
import CoreGraphics

final class CaptureCoordinator {
    private let store: ClipboardStore
    private var process: Process?
    private var captureURL: URL?
    private var stopping = false
    var onStateChange: (() -> Void)?
    var onError: ((String) -> Void)?
    var isCapturing: Bool { process != nil }

    init(store: ClipboardStore) { self.store = store }

    func capture() {
        guard process == nil else { return }
        guard CGPreflightScreenCaptureAccess() else {
            // Request system consent only after an explicit capture action.
            CGRequestScreenCaptureAccess()
            onError?("需要屏幕录制权限。请在「系统设置 → 隐私与安全性 → 屏幕与系统音频录制」中允许 SnapShelf，然后退出并重新打开本应用。")
            return
        }
        let url = store.newCaptureURL()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-x", "-t", "png", url.path]
        // A file avoids pipe backpressure; no screenshots or clipboard contents enter logs.
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async { self?.complete(url: url, status: finished.terminationStatus) }
        }
        process = task
        captureURL = url
        onStateChange?()
        do { try task.run() }
        catch {
            process = nil
            captureURL = nil
            store.discardCapture(url)
            onStateChange?()
            onError?("无法启动系统截图：\(error.localizedDescription)")
        }
    }

    private func complete(url: URL, status: Int32) {
        process = nil
        captureURL = nil
        onStateChange?()
        guard !stopping else { store.discardCapture(url); return }
        // Esc normally returns a nonzero status without producing a file.
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        guard status == 0 else {
            store.discardCapture(url)
            onError?("系统截图未完成，请重试。")
            return
        }
        do { try store.publish(url) }
        catch { store.discardCapture(url); onError?(error.localizedDescription) }
    }

    func shutdown() {
        stopping = true
        if let process, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        if let captureURL { store.discardCapture(captureURL) }
    }
}
