import AppKit
import XCTest
@testable import SnapShelf

final class ClipboardStoreTests: XCTestCase {
    private var root: URL!
    private var board: NSPasteboard!
    private var store: ClipboardStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("SnapShelfTests-\(UUID().uuidString)")
        board = NSPasteboard(name: NSPasteboard.Name("SnapShelfTests-\(UUID().uuidString)"))
        store = try ClipboardStore(pasteboard: board, directory: root.appendingPathComponent("Captures"))
    }

    override func tearDownWithError() throws {
        store.shutdown()
        board.releaseGlobally()
        try FileManager.default.removeItem(at: root)
    }

    private func makePNG() throws -> URL {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 3, pixelsHigh: 2,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<2 { for x in 0..<3 {
            let pixel = bitmap.bitmapData!.advanced(by: y * bitmap.bytesPerRow + x * 4)
            pixel[0] = 30; pixel[1] = 120; pixel[2] = 240; pixel[3] = 255
        } }
        let url = store.newCaptureURL()
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }

    func testClipboardSupportsImagesAndFinderFiles() throws {
        let url = try makePNG()
        try store.publish(url)
        XCTAssertNotNil(board.data(forType: .png))
        XCTAssertNotNil(board.data(forType: .tiff))
        let decoded = NSBitmapImageRep(data: board.data(forType: .png)!)
        XCTAssertEqual(decoded?.pixelsWide, 3)
        XCTAssertEqual(decoded?.pixelsHigh, 2)
        XCTAssertTrue(board.canReadObject(forClasses: [NSImage.self], options: nil))
        let files = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        XCTAssertEqual(files, [url])
        XCTAssertEqual(board.pasteboardItems?.count, 1)
    }

    func testTextReplacementDeletesTemporaryFileAndPreservesTextAndSavedCopy() throws {
        let url = try makePNG()
        try store.publish(url)
        let saved = root.appendingPathComponent("Saved.png")
        try FileManager.default.copyItem(at: url, to: saved)
        board.clearContents()
        board.setString("新的文字", forType: .string)
        store.checkClipboard()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.path))
        XCTAssertNil(store.currentFile)
        store.shutdown()
        XCTAssertEqual(board.string(forType: .string), "新的文字")
    }

    func testCopyingAnotherFileDoesNotDeleteThatSourceFile() throws {
        let screenshot = try makePNG()
        try store.publish(screenshot)
        let externalFile = root.appendingPathComponent("Other.txt")
        try Data("keep".utf8).write(to: externalFile)
        board.clearContents()
        XCTAssertTrue(board.writeObjects([externalFile as NSURL]))
        store.checkClipboard()
        XCTAssertFalse(FileManager.default.fileExists(atPath: screenshot.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalFile.path))
    }

    func testAnotherScreenshotRetiresPreviousAndReadsDoNotDeleteCurrent() throws {
        let first = try makePNG()
        try store.publish(first)
        let second = try makePNG()
        try store.publish(second)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        _ = board.data(forType: .png)
        store.checkClipboard()
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        XCTAssertEqual(store.currentFile, second)
        store.clearCurrent()
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
        XCTAssertTrue(board.types?.isEmpty ?? true)
    }

    func testInvalidCaptureLeavesExistingClipboardUntouched() throws {
        board.clearContents()
        board.setString("保留", forType: .string)
        let count = board.changeCount
        let invalid = store.newCaptureURL()
        try Data("not an image".utf8).write(to: invalid)
        XCTAssertThrowsError(try store.publish(invalid))
        XCTAssertEqual(board.changeCount, count)
        XCTAssertEqual(board.string(forType: .string), "保留")
    }

    func testOrphanCleanupIsRestrictedToOwnedPNGs() throws {
        let orphan = try makePNG()
        let other = store.directory.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: other)
        let outside = root.appendingPathComponent("SnapShelf-outside.png")
        try Data("keep".utf8).write(to: outside)
        XCTAssertThrowsError(try store.publish(outside))
        store.discardCapture(outside)
        try store.removeOrphans()
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
    }

    func testMonitoringAutomaticallyCleansReplacement() throws {
        let url = try makePNG()
        try store.publish(url)
        let cleaned = expectation(description: "Clipboard watcher retires the screenshot")
        store.onChange = { [weak store] in
            if store?.currentFile == nil { cleaned.fulfill() }
        }
        store.startMonitoring()
        board.clearContents()
        board.setString("replacement", forType: .string)
        wait(for: [cleaned], timeout: 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        store.onChange = nil
    }
}
