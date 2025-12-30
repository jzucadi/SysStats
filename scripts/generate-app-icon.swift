#!/usr/bin/env swift

import Cocoa

// App Icon Generator for SysStats
// Generates a gauge-style icon in all required sizes

let sizes: [(name: String, size: Int)] = [
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

func generateIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(size)
    let center = CGPoint(x: s/2, y: s/2)
    let radius = s * 0.42
    let padding = s * 0.08

    // Background - rounded square with gradient
    let bgRect = NSRect(x: padding, y: padding, width: s - padding*2, height: s - padding*2)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: s * 0.2, yRadius: s * 0.2)

    // Gradient background
    let gradient = NSGradient(colors: [
        NSColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0),
        NSColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
    ])!
    gradient.draw(in: bgPath, angle: -90)

    // Outer ring
    ctx.setStrokeColor(NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1.0).cgColor)
    ctx.setLineWidth(s * 0.02)
    ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    // Gauge arc background
    let arcStart: CGFloat = .pi * 0.8
    let arcEnd: CGFloat = .pi * 0.2
    ctx.setStrokeColor(NSColor(red: 0.25, green: 0.25, blue: 0.3, alpha: 1.0).cgColor)
    ctx.setLineWidth(s * 0.06)
    ctx.setLineCap(.round)
    ctx.addArc(center: center, radius: radius * 0.75, startAngle: arcStart, endAngle: arcEnd, clockwise: true)
    ctx.strokePath()

    // Gauge arc - colored sections
    // Green section (0-50%)
    let greenEnd: CGFloat = .pi * 0.5
    ctx.setStrokeColor(NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0).cgColor)
    ctx.setLineWidth(s * 0.06)
    ctx.addArc(center: center, radius: radius * 0.75, startAngle: arcStart, endAngle: greenEnd, clockwise: true)
    ctx.strokePath()

    // Yellow section (50-75%)
    let yellowEnd: CGFloat = .pi * 0.35
    ctx.setStrokeColor(NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0).cgColor)
    ctx.addArc(center: center, radius: radius * 0.75, startAngle: greenEnd, endAngle: yellowEnd, clockwise: true)
    ctx.strokePath()

    // Red section (75-100%)
    ctx.setStrokeColor(NSColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1.0).cgColor)
    ctx.addArc(center: center, radius: radius * 0.75, startAngle: yellowEnd, endAngle: arcEnd, clockwise: true)
    ctx.strokePath()

    // Needle pointing to ~40%
    let needleAngle: CGFloat = .pi * 0.55
    let needleLength = radius * 0.55
    let needleEnd = CGPoint(
        x: center.x + cos(needleAngle) * needleLength,
        y: center.y + sin(needleAngle) * needleLength
    )

    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(s * 0.03)
    ctx.setLineCap(.round)
    ctx.move(to: center)
    ctx.addLine(to: needleEnd)
    ctx.strokePath()

    // Center dot
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - s*0.04, y: center.y - s*0.04, width: s*0.08, height: s*0.08))

    // Small indicator dots
    let dotRadius = s * 0.015
    let dotDistance = radius * 0.9
    for i in 0..<9 {
        let angle = arcStart - CGFloat(i) * (arcStart - arcEnd) / 8.0
        let dotCenter = CGPoint(
            x: center.x + cos(angle) * dotDistance,
            y: center.y + sin(angle) * dotDistance
        )
        ctx.setFillColor(NSColor(white: 0.5, alpha: 1.0).cgColor)
        ctx.fillEllipse(in: CGRect(x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius, width: dotRadius*2, height: dotRadius*2))
    }

    image.unlockFocus()

    return image
}

func saveIcon(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created: \(path)")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// Get output directory
let args = CommandLine.arguments
let outputDir: String
if args.count > 1 {
    outputDir = args[1]
} else {
    // Default to AppIcon.appiconset in the project
    let scriptPath = args[0]
    let scriptsDir = (scriptPath as NSString).deletingLastPathComponent
    outputDir = (scriptsDir as NSString).appendingPathComponent("../SysStats/Assets.xcassets/AppIcon.appiconset")
}

print("Generating app icons to: \(outputDir)")

// Generate all sizes
for (name, size) in sizes {
    let icon = generateIcon(size: size)
    let path = (outputDir as NSString).appendingPathComponent(name)
    saveIcon(icon, to: path)
}

print("\nDone! App icons generated successfully.")
