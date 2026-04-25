#!/usr/bin/env swift
//
// Renders the DMG installer background as a 540×380 PNG.
// Dark gradient + subtle arrow hint, matching the app icon's tone.
//
// Usage: swift Scripts/make_dmg_background.swift <output.png>

import AppKit
import CoreGraphics

let out = CommandLine.arguments[1]

let width = 540
let height = 380
let scale = 2     // @2x for retina

let pxW = width * scale
let pxH = height * scale

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: pxW, height: pxH,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

// Dark vertical gradient — matches the icon's bg #18171A
let top = CGColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1.0)
let bot = CGColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1.0)
let grad = CGGradient(colorsSpace: cs, colors: [top, bot] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    grad,
    start: CGPoint(x: 0, y: CGFloat(height)),
    end:   CGPoint(x: 0, y: 0),
    options: []
)

// Subtle inner glow / vignette: a faint radial highlight in the upper-center
let glowCenter = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) * 0.7)
let glowColors = [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.05),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
] as CFArray
let glow = CGGradient(colorsSpace: cs, colors: glowColors, locations: [0, 1])!
ctx.drawRadialGradient(
    glow,
    startCenter: glowCenter, startRadius: 0,
    endCenter:   glowCenter, endRadius: 220,
    options: []
)

// Centred arrow — fine outlined chevron pointing right between icon slots
let arrowColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.18)
ctx.setStrokeColor(arrowColor)
ctx.setLineWidth(2.0)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

let arrowCenter = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) * 0.55)
let arrowSize: CGFloat = 22
let chevron = CGMutablePath()
chevron.move(to: CGPoint(x: arrowCenter.x - arrowSize, y: arrowCenter.y + arrowSize / 2))
chevron.addLine(to: CGPoint(x: arrowCenter.x, y: arrowCenter.y))
chevron.addLine(to: CGPoint(x: arrowCenter.x - arrowSize, y: arrowCenter.y - arrowSize / 2))
ctx.addPath(chevron)
ctx.strokePath()

// Hint text below
let hint = "Drag Manfath to Applications"
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(white: 1, alpha: 0.55),
]
let attr = NSAttributedString(string: hint, attributes: attrs)
let textSize = attr.size()
let textPoint = CGPoint(
    x: (CGFloat(width) - textSize.width) / 2,
    y: CGFloat(height) * 0.18
)

NSGraphicsContext.saveGraphicsState()
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = nsCtx
attr.draw(at: textPoint)
NSGraphicsContext.restoreGraphicsState()

guard let cgimg = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: cgimg)
rep.size = NSSize(width: width, height: height)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(pxW)×\(pxH))")
