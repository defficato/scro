// Generates scro's app icon with Core Graphics — no design tools needed.
// Design: dark shadcn-style tile, a stack of screenshot cards (history),
// viewfinder brackets (capture), indigo status dot (accent).
//
// Usage (from repo root):  swift scripts/IconGen.swift
// Then:                    iconutil -c icns build/AppIcon.iconset -o AppIcon.icns
// Or simply:               ./scripts/make-icon.sh

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let design: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedRectPath(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawCard(
    _ ctx: CGContext,
    center: CGPoint,
    size: CGSize,
    rotation: CGFloat,
    radius: CGFloat,
    fill: CGColor,
    stroke: CGColor? = nil,
    strokeWidth: CGFloat = 0,
    shadowed: Bool = false
) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: rotation * .pi / 180)
    let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    let path = roundedRectPath(rect, radius)

    if shadowed {
        ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 42, color: color(0x000000, 0.38))
    }
    ctx.addPath(path)
    ctx.setFillColor(fill)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    if let stroke, strokeWidth > 0 {
        ctx.addPath(path)
        ctx.setStrokeColor(stroke)
        ctx.setLineWidth(strokeWidth)
        ctx.strokePath()
    }
    ctx.restoreGState()
}

/// Four corner brackets — the ⇧⌘4 selection motif.
func drawViewfinder(
    _ ctx: CGContext,
    center: CGPoint,
    cardSize: CGSize,
    rotation: CGFloat
) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: rotation * .pi / 180)

    let inset: CGFloat = 46
    let arm: CGFloat = 76
    let halfW = cardSize.width / 2 - inset
    let halfH = cardSize.height / 2 - inset

    ctx.setStrokeColor(color(0x18181B))
    ctx.setLineWidth(20)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // top-left
    ctx.move(to: CGPoint(x: -halfW, y: -halfH + arm))
    ctx.addLine(to: CGPoint(x: -halfW, y: -halfH))
    ctx.addLine(to: CGPoint(x: -halfW + arm, y: -halfH))
    // top-right
    ctx.move(to: CGPoint(x: halfW - arm, y: -halfH))
    ctx.addLine(to: CGPoint(x: halfW, y: -halfH))
    ctx.addLine(to: CGPoint(x: halfW, y: -halfH + arm))
    // bottom-right
    ctx.move(to: CGPoint(x: halfW, y: halfH - arm))
    ctx.addLine(to: CGPoint(x: halfW, y: halfH))
    ctx.addLine(to: CGPoint(x: halfW - arm, y: halfH))
    // bottom-left
    ctx.move(to: CGPoint(x: -halfW + arm, y: halfH))
    ctx.addLine(to: CGPoint(x: -halfW, y: halfH))
    ctx.addLine(to: CGPoint(x: -halfW, y: halfH - arm))
    ctx.strokePath()

    ctx.restoreGState()
}

func drawIcon(pixelSize: CGFloat) -> CGImage {
    let ctx = CGContext(
        data: nil,
        width: Int(pixelSize),
        height: Int(pixelSize),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: pixelSize / design, y: pixelSize / design)
    ctx.translateBy(x: 0, y: design)
    ctx.scaleBy(x: 1, y: -1)   // y-down, like a design tool

    let inset: CGFloat = 100
    let rect = CGRect(x: inset, y: inset, width: design - 2 * inset, height: design - 2 * inset)
    let squircle = roundedRectPath(rect, 188)

    // Tile with a soft drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 12), blur: 36, color: color(0x000000, 0.32))
    ctx.addPath(squircle)
    ctx.setFillColor(color(0x14141A))
    ctx.fillPath()
    ctx.restoreGState()

    // Background gradient + top sheen.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    let rgb = CGColorSpace(name: CGColorSpace.sRGB)!
    let background = CGGradient(
        colorsSpace: rgb,
        colors: [color(0x2C2C36), color(0x0F0F14)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        background,
        start: CGPoint(x: rect.minX, y: rect.minY),
        end: CGPoint(x: rect.maxX, y: rect.maxY),
        options: []
    )

    let sheen = CGGradient(
        colorsSpace: rgb,
        colors: [color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        sheen,
        start: CGPoint(x: 0, y: rect.minY),
        end: CGPoint(x: 0, y: rect.minY + 340),
        options: []
    )
    ctx.restoreGState()

    // Hairline inner border.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.setStrokeColor(color(0xFFFFFF, 0.10))
    ctx.setLineWidth(3)
    ctx.strokePath()
    ctx.restoreGState()

    // History stack: two ghost cards peeking out top-right.
    drawCard(
        ctx,
        center: CGPoint(x: 592, y: 548),
        size: CGSize(width: 348, height: 278),
        rotation: 9,
        radius: 44,
        fill: color(0xFFFFFF, 0.10)
    )
    drawCard(
        ctx,
        center: CGPoint(x: 542, y: 532),
        size: CGSize(width: 366, height: 292),
        rotation: 4.5,
        radius: 44,
        fill: color(0xFFFFFF, 0.22),
        stroke: color(0xFFFFFF, 0.12),
        strokeWidth: 3
    )

    // Front card with viewfinder brackets.
    let frontSize = CGSize(width: 400, height: 320)
    let frontCenter = CGPoint(x: 468, y: 500)
    let frontRotation: CGFloat = -3
    drawCard(
        ctx,
        center: frontCenter,
        size: frontSize,
        rotation: frontRotation,
        radius: 46,
        fill: color(0xFAFAFA),
        shadowed: true
    )
    drawViewfinder(ctx, center: frontCenter, cardSize: frontSize, rotation: frontRotation)

    // Indigo status dot, notched into the front card's corner.
    let dotCenter = CGPoint(x: 664, y: 682)
    let rgb2 = CGColorSpace(name: CGColorSpace.sRGB)!

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 30, color: color(0x6366F1, 0.55))
    ctx.setFillColor(color(0x101014))
    ctx.fillEllipse(in: CGRect(x: dotCenter.x - 56, y: dotCenter.y - 56, width: 112, height: 112))
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: dotCenter.x - 42, y: dotCenter.y - 42, width: 84, height: 84))
    ctx.clip()
    let dotGradient = CGGradient(
        colorsSpace: rgb2,
        colors: [color(0x8B8CF9), color(0x4F46E5)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        dotGradient,
        start: CGPoint(x: dotCenter.x - 42, y: dotCenter.y - 42),
        end: CGPoint(x: dotCenter.x + 42, y: dotCenter.y + 42),
        options: []
    )
    ctx.restoreGState()

    return ctx.makeImage()!
}

// MARK: - Export iconset

let fm = FileManager.default
let outDir = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("build/AppIcon.iconset")
try? fm.removeItem(at: outDir)
try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
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

for (name, px) in entries {
    let image = drawIcon(pixelSize: CGFloat(px))
    let url = outDir.appendingPathComponent(name)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("could not create image destination for \(name)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("could not write \(name)")
    }
    print("wrote \(name) (\(px)px)")
}

print("iconset → \(outDir.path)")
