import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let background = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 210, yRadius: 210)
        NSGradient(starting: NSColor(calibratedRed: 0.15, green: 0.60, blue: 0.97, alpha: 1),
                   ending: NSColor(calibratedRed: 0.14, green: 0.26, blue: 0.84, alpha: 1))!.draw(in: background, angle: -65)
        NSColor.white.setStroke()
        let frame = NSBezierPath()
        frame.lineWidth = 48
        frame.lineCapStyle = .round
        frame.lineJoinStyle = .round
        for (x, y, dx, dy) in [(260.0, 260.0, 1.0, 1.0), (764, 260, -1, 1), (260, 764, 1, -1), (764, 764, -1, -1)] {
            frame.move(to: NSPoint(x: x, y: y + dy * 140))
            frame.line(to: NSPoint(x: x, y: y))
            frame.line(to: NSPoint(x: x + dx * 140, y: y))
        }
        frame.stroke()
        NSColor.white.withAlphaComponent(0.94).setFill()
        NSBezierPath(roundedRect: NSRect(x: 377, y: 405, width: 270, height: 214), xRadius: 36, yRadius: 36).fill()
        NSColor(calibratedRed: 0.20, green: 0.42, blue: 0.90, alpha: 1).setFill()
        let mountain = NSBezierPath()
        mountain.move(to: NSPoint(x: 407, y: 438))
        mountain.line(to: NSPoint(x: 486, y: 540))
        mountain.line(to: NSPoint(x: 538, y: 482))
        mountain.line(to: NSPoint(x: 576, y: 525))
        mountain.line(to: NSPoint(x: 620, y: 438))
        mountain.close()
        mountain.fill()
        NSBezierPath(ovalIn: NSRect(x: 559, y: 555, width: 38, height: 38)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
