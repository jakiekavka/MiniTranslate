#!/usr/bin/env swift

import AppKit
import Foundation

let outputDir: String
if CommandLine.arguments.count > 1 {
    outputDir = CommandLine.arguments[1]
} else {
    let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
    outputDir = (scriptDir as NSString).appendingPathComponent("../.build/AppIcon.iconset")
}

let iconsetDir = outputDir
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(Int, Int)] = [
    (16, 1), (32, 2),     // 16x16 @1x and @2x
    (32, 1), (64, 2),     // 32x32 @1x and @2x
    (128, 1), (256, 2),   // 128x128 @1x and @2x
    (256, 1), (512, 2),   // 256x256 @1x and @2x
    (512, 1), (1024, 2),  // 512x512 @1x and @2x
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    // Background rounded rect
    let inset = size * 0.08
    let cornerRadius = size * 0.22
    let bgRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Gradient background
    if let ctx = NSGraphicsContext.current?.cgContext {
        let colors = [
            CGColor(red: 0.25, green: 0.45, blue: 0.90, alpha: 1.0),
            CGColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 1.0)
        ]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors as CFArray,
                                      locations: [0.0, 1.0]) {
            ctx.saveGState()
            bgPath.addClip()
            ctx.drawLinearGradient(gradient,
                                    start: CGPoint(x: 0, y: 0),
                                    end: CGPoint(x: size, y: size),
                                    options: [])
            ctx.restoreGState()
        } else {
            // Fallback solid color
            NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.90, alpha: 1.0).setFill()
            bgPath.fill()
        }
    } else {
        NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.90, alpha: 1.0).setFill()
        bgPath.fill()
    }

    // Draw "译" character in white
    let fontSize = size * 0.48
    let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let text = "译"
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let textSize = text.size(withAttributes: attributes)
    let textOrigin = NSPoint(
        x: (size - textSize.width) / 2,
        y: (size - textSize.height) / 2 - size * 0.02
    )
    text.draw(at: textOrigin, withAttributes: attributes)

    image.unlockFocus()
    return image
}

for (pixelSize, scale) in sizes {
    let image = drawIcon(size: CGFloat(pixelSize))

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(pixelSize)x\(pixelSize) icon")
        continue
    }

    var fileName: String
    if scale == 2 {
        let baseSize = pixelSize / 2
        fileName = "icon_\(baseSize)x\(baseSize)@2x.png"
    } else {
        fileName = "icon_\(pixelSize)x\(pixelSize).png"
    }

    let filePath = (iconsetDir as NSString).appendingPathComponent(fileName)
    try png.write(to: URL(fileURLWithPath: filePath))
    print("Generated \(fileName)")
}

print("\nIcons generated in: \(iconsetDir)")
print("Run: iconutil -c icns \(iconsetDir)")
