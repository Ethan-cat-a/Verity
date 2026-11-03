import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: GenerateAppIcon.swift <output.iconset>")
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    NSBezierPath(rect: canvas).fill()

    let s = CGFloat(size)
    let ballRect = NSRect(x: s * 0.065, y: s * 0.065, width: s * 0.87, height: s * 0.87)
    let ball = NSBezierPath(ovalIn: ballRect)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0.15, alpha: 0.30)
    shadow.shadowBlurRadius = s * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.025)
    shadow.set()
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.99, blue: 0.30, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.0, alpha: 1),
        NSColor(calibratedRed: 0.87, green: 0.60, blue: 0.0, alpha: 1)
    ])!
    gradient.draw(in: ball, angle: -35)
    NSGraphicsContext.current?.compositingOperation = .sourceOver
    NSColor(calibratedWhite: 0.08, alpha: 0.35).setStroke()
    ball.lineWidth = max(1, s * 0.009)
    ball.stroke()

    NSShadow().set()
    NSColor(calibratedWhite: 0.015, alpha: 1).setFill()
    let leftEye = NSBezierPath(ovalIn: NSRect(x: s * 0.285, y: s * 0.565, width: s * 0.105, height: s * 0.19))
    let rightEye = NSBezierPath(ovalIn: NSRect(x: s * 0.610, y: s * 0.565, width: s * 0.105, height: s * 0.19))
    leftEye.fill()
    rightEye.fill()

    let mouth = NSBezierPath()
    mouth.move(to: NSPoint(x: s * 0.245, y: s * 0.475))
    mouth.curve(
        to: NSPoint(x: s * 0.755, y: s * 0.475),
        controlPoint1: NSPoint(x: s * 0.35, y: s * 0.245),
        controlPoint2: NSPoint(x: s * 0.65, y: s * 0.245)
    )
    mouth.lineWidth = max(1.4, s * 0.025)
    mouth.lineCapStyle = .round
    NSColor(calibratedWhite: 0.015, alpha: 1).setStroke()
    mouth.stroke()

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in iconSizes {
    let data = drawIcon(size: size)
    try data.write(to: output.appendingPathComponent(name), options: .atomic)
}
print("Created VERITY app icon set at " + output.path)
