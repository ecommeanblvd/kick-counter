#!/usr/bin/env swift
// Generates a placeholder 1024x1024 opaque app icon: coral background
// (matching AccentColor light) with a centered white heart. Temporary —
// replace with a designed icon before App Store release.
//
// Usage: swift scripts/make-placeholder-icon.swift <output.png>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("Usage: swift make-placeholder-icon.swift <output.png>\n".utf8))
    exit(1)
}
let outputPath = CommandLine.arguments[1]

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
// No alpha channel: the App Store rejects an icon with one.
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    FileHandle.standardError.write(Data("Failed to create CGContext\n".utf8))
    exit(1)
}

func setFill(_ context: CGContext, _ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) {
    context.setFillColor(CGColor(colorSpace: colorSpace, components: [red, green, blue, 1.0])!)
}

// Background: coral matching AccentColor light (#D85D69).
setFill(context, 0.847, 0.365, 0.412)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

/// Draws a classic heart — two rounded lobes on top meeting at a top-center
/// notch, a single pointed tip at the bottom — into `path`, sized by `scale`
/// (the heart's total width) and centered at (centerX, centerY).
///
/// Built from a well-known heart SVG path (viewBox 0-32, bounds x:[2,30]
/// y:[2,29.239]) by mapping its coordinates into a local frame centered on
/// that path's own bounding box: `lx = (x - 16) / 28 * scale`,
/// `ly = (15.6195 - y) / 28 * scale`. The path's bounding box is symmetric
/// around (16, 15.6195) in both axes, so this local frame is automatically
/// centered at (0, 0) — translating by (centerX, centerY) centers the drawn
/// heart's bounding box there exactly, and `scale` maps directly to the
/// heart's on-canvas width. CGContext here is y-up; the `15.6195 - y` flip
/// accounts for the source path's y-down SVG convention (larger y = lower on
/// screen), so the bottom tip lands below center and the top lobes above it.
func addHeart(to path: CGMutablePath, centerX: CGFloat, centerY: CGFloat, scale: CGFloat) {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: centerX + (x - 16) / 28 * scale, y: centerY + (15.6195 - y) / 28 * scale)
    }
    path.move(to: p(16, 29.239))
    path.addCurve(to: p(2, 10.5), control1: p(16, 29.239), control2: p(2, 18))
    path.addCurve(to: p(10.5, 2), control1: p(2, 5.806), control2: p(5.806, 2))
    path.addCurve(to: p(16, 4.5), control1: p(13.703, 2), control2: p(16, 4.5))
    path.addCurve(to: p(21.5, 2), control1: p(16, 4.5), control2: p(18.297, 2))
    path.addCurve(to: p(30, 10.5), control1: p(26.194, 2), control2: p(30, 5.806))
    path.addCurve(to: p(16, 29.239), control1: p(30, 18), control2: p(16, 29.239))
    path.closeSubpath()
}

let centerX = CGFloat(size) / 2
let centerY = CGFloat(size) / 2

// Heart: white, ~58% of the canvas width, bounding box centered on the canvas.
let heart = CGMutablePath()
addHeart(to: heart, centerX: centerX, centerY: centerY, scale: CGFloat(size) * 0.58)
setFill(context, 1.0, 1.0, 1.0)
context.addPath(heart)
context.fillPath()

guard let cgImage = context.makeImage() else {
    FileHandle.standardError.write(Data("Failed to create CGImage\n".utf8))
    exit(1)
}

let url = URL(fileURLWithPath: outputPath) as CFURL
guard let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("Failed to create image destination\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("Failed to write PNG\n".utf8))
    exit(1)
}

print("Wrote \(outputPath) (\(size)x\(size))")
