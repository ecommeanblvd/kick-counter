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

func addHeart(to path: CGMutablePath, centerX: CGFloat, centerY: CGFloat, scale: CGFloat) {
    let w = scale
    let h = scale * 0.9
    // Unit heart in a local frame where y=0 is the bottom tip and y=h is the top
    // of the lobes, translated to (centerX, centerY). CGContext is y-up, so this
    // maps directly without flipping.
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: centerX + x, y: centerY + y - h * 0.5) }
    path.move(to: p(0, h * 0.3))
    path.addCurve(to: p(-w * 0.5, h * 0.8), control1: p(0, h * 0.05), control2: p(-w * 0.5, h * 0.5))
    path.addCurve(to: p(-w * 0.15, h), control1: p(-w * 0.5, h * 1.05), control2: p(-w * 0.32, h))
    path.addCurve(to: p(0, h * 0.75), control1: p(-w * 0.03, h), control2: p(0, h * 0.9))
    path.addCurve(to: p(w * 0.15, h), control1: p(0, h * 0.9), control2: p(w * 0.03, h))
    path.addCurve(to: p(w * 0.5, h * 0.8), control1: p(w * 0.32, h), control2: p(w * 0.5, h * 1.05))
    path.addCurve(to: p(0, h * 0.3), control1: p(w * 0.5, h * 0.5), control2: p(0, h * 0.05))
    path.closeSubpath()
}

let centerX = CGFloat(size) / 2
let centerY = CGFloat(size) / 2

// Outer heart: white.
let outerHeart = CGMutablePath()
addHeart(to: outerHeart, centerX: centerX, centerY: centerY, scale: CGFloat(size) * 0.62)
setFill(context, 1.0, 1.0, 1.0)
context.addPath(outerHeart)
context.fillPath()

// Inner heart: subtle lighter coral, slightly smaller, for depth.
let innerHeart = CGMutablePath()
addHeart(to: innerHeart, centerX: centerX, centerY: centerY - CGFloat(size) * 0.04, scale: CGFloat(size) * 0.34)
setFill(context, 0.957, 0.557, 0.588)
context.addPath(innerHeart)
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
