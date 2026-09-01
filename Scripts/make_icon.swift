// Generates MemWatch.app icon: a rounded memory-chip glyph on a gradient.
// Usage: swift make_icon.swift <output_dir>
import AppKit
import CoreGraphics
import Foundation

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath

let iconsetDir = (outputDir as NSString).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Background: rounded square with vertical gradient (indigo → violet)
    let inset = size * 0.02
    let bgRect = rect.insetBy(dx: inset, dy: inset)
    let radius = size * 0.22
    let bgPath = CGPath(
        roundedRect: bgRect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colors = [
        CGColor(red: 0.35, green: 0.40, blue: 0.95, alpha: 1.0),   // indigo
        CGColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1.0)    // violet
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: bgRect.maxY),
            end: CGPoint(x: bgRect.width, y: bgRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Memory chip: rounded rect body
    let chipInset = size * 0.26
    let chipRect = rect.insetBy(dx: chipInset, dy: chipInset)
    let chipRadius = size * 0.06
    let chipPath = CGPath(
        roundedRect: chipRect,
        cornerWidth: chipRadius,
        cornerHeight: chipRadius,
        transform: nil
    )

    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    ctx.addPath(chipPath)
    ctx.fillPath()

    // Chip pins (short lines on left/right edges)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9))
    ctx.setLineCap(.round)
    ctx.setLineWidth(size * 0.028)

    let pinLen = size * 0.075
    let pinRows: [CGFloat] = [0.40, 0.50, 0.60]
    for frac in pinRows {
        let y = chipRect.minY + chipRect.height * frac
        // left
        ctx.move(to: CGPoint(x: chipRect.minX - pinLen * 0.5, y: y))
        ctx.addLine(to: CGPoint(x: chipRect.minX + size * 0.02, y: y))
        // right
        ctx.move(to: CGPoint(x: chipRect.maxX - size * 0.02, y: y))
        ctx.addLine(to: CGPoint(x: chipRect.maxX + pinLen * 0.5, y: y))
    }
    ctx.strokePath()

    // Inner fill bars suggesting memory usage (3 bars, increasing height)
    let barArea = chipRect.insetBy(dx: size * 0.075, dy: size * 0.075)
    let barCount = 3
    let barGap = size * 0.035
    let totalGap = barGap * CGFloat(barCount - 1)
    let barWidth = (barArea.width - totalGap) / CGFloat(barCount)
    let heights: [CGFloat] = [0.45, 0.72, 1.0]

    for (i, hFrac) in heights.enumerated() {
        let x = barArea.minX + CGFloat(i) * (barWidth + barGap)
        let h = barArea.height * hFrac
        let barRect = CGRect(
            x: x,
            y: barArea.maxY - h,
            width: barWidth,
            height: h
        )
        let barPath = CGPath(
            roundedRect: barRect,
            cornerWidth: barWidth * 0.28,
            cornerHeight: barWidth * 0.28,
            transform: nil
        )
        // Gradient per bar: warm → hot as it gets taller
        let t = CGFloat(i) / CGFloat(barCount - 1)
        ctx.setFillColor(
            CGColor(
                red: 0.95 - 0.15 * t,
                green: 0.55 - 0.30 * t,
                blue: 0.30 + 0.10 * t,
                alpha: 1.0
            )
        )
        ctx.addPath(barPath)
        ctx.fillPath()
    }

    return ctx.makeImage()
}

// Write PNG for every iconset size we need
let sizes: [(px: Int, name: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for entry in sizes {
    guard let cgImage = drawIcon(size: CGFloat(entry.px)) else { continue }
    let url = URL(fileURLWithPath: (iconsetDir as NSString).appendingPathComponent(entry.name))
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        continue
    }
    CGImageDestinationAddImage(dest, cgImage, nil)
    CGImageDestinationFinalize(dest)
}

print("Wrote iconset to \(iconsetDir)")
