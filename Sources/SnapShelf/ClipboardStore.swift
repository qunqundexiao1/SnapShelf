import AppKit

/// Owns only files inside this app's private cache. Never deletes copied source files.
final class ClipboardStore {
    enum StoreError: LocalizedError {
        case invalidImage, clipboardWriteFailed, outsideCache
        var errorDescription: String? {
            switch self {
            case .invalidImage: return "截图文件无法读取，请重新截图。"
            case .clipboardWriteFailed: return "无法写入剪贴板，请重新截图。"
            case .outsideCache: return "临时截图路径不属于本应用。"
            }
        }
    }

    let directory: URL
    private let pasteboard: NSPasteboard
    private(set) var currentFile: URL?
    private var ownedChangeCount: Int?
    private var timer: Timer?
    var onChange: (() -> Void)?
    var onCleanupError: ((Error) -> Void)?

    init(pasteboard: NSPasteboard = .general, directory: URL? = nil) throws {
        self.pasteboard = pasteboard
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.local.snapshelf/Captures", isDirectory: true)
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: self.directory.path)
    }

    func removeOrphans() throws {
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where url.pathExtension == "png" && url.lastPathComponent.hasPrefix("SnapShelf-") {
            try FileManager.default.removeItem(at: url)
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.checkClipboard() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func newCaptureURL() -> URL {
        directory.appendingPathComponent("SnapShelf-\(UUID().uuidString).png")
    }

    func publish(_ url: URL) throws {
        guard isManaged(url) else { throw StoreError.outsideCache }
        let png = try Data(contentsOf: url)
        guard let image = NSImage(data: png), image.isValid, let tiff = image.tiffRepresentation else {
            throw StoreError.invalidImage
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        item.setData(png, forType: .png)
        item.setData(tiff, forType: .tiff)
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw StoreError.clipboardWriteFailed }
        let previous = currentFile
        currentFile = url
        ownedChangeCount = pasteboard.changeCount
        if let previous, previous != url { removeManagedFile(previous) }
        onChange?()
    }

    func checkClipboard() {
        guard let count = ownedChangeCount, pasteboard.changeCount != count else { return }
        // Forget ownership before invoking callbacks, which may run another clipboard operation.
        ownedChangeCount = nil
        if let file = currentFile { removeManagedFile(file) }
        currentFile = nil
        onChange?()
    }

    func clearCurrent() {
        if let count = ownedChangeCount, pasteboard.changeCount == count { pasteboard.clearContents() }
        ownedChangeCount = nil
        if let file = currentFile { removeManagedFile(file) }
        currentFile = nil
        onChange?()
    }

    func discardCapture(_ url: URL) { removeManagedFile(url) }

    func shutdown() {
        timer?.invalidate()
        timer = nil
        clearCurrent()
    }

    private func isManaged(_ url: URL) -> Bool {
        url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL
            && url.lastPathComponent.hasPrefix("SnapShelf-") && url.pathExtension == "png"
    }

    private func removeManagedFile(_ url: URL) {
        guard isManaged(url), FileManager.default.fileExists(atPath: url.path) else { return }
        do { try FileManager.default.removeItem(at: url) }
        catch { onCleanupError?(error) }
    }
}
