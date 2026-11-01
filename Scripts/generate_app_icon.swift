#!/usr/bin/env swift
// Draws the 1024×1024 app icon: rising bar chart + gold "growth" coin on an
// indigo gradient. Shapes only (no fonts or SF Symbols), opaque, as the App
// Store requires.
//
// Usage: swift Scripts/generate_app_icon.swift <output.png>

import AppKit
import CoreGraphics

let size = 1024
let output = CommandLine.arguments.dropFirst().first
    ?? "MiniIdleTycoon/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

func linearGradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
               colors: colors as CFArray, locations: nil)!
}

let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Flip to top-left origin so coordinates read like a design file.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

// MARK: Background

ctx.drawLinearGradient(linearGradient([color(0x2A1B7A), color(0x6A2CE0)]),
                       start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1024, y: 1024), options: [])

// Soft glow behind the chart.
ctx.drawRadialGradient(linearGradient([color(0xFFFFFF, alpha: 0.18), color(0xFFFFFF, alpha: 0)]),
                       startCenter: CGPoint(x: 470, y: 600), startRadius: 0,
                       endCenter: CGPoint(x: 470, y: 600), endRadius: 520, options: [])

// MARK: Bar Chart

let baseline: CGFloat = 830
let bars: [(x: CGFloat, height: CGFloat, alpha: CGFloat)] = [
    (170, 230, 0.70),
    (370, 380, 0.85),
    (570, 540, 1.00),
]
for bar in bars {
    let rect = CGRect(x: bar.x, y: baseline - bar.height, width: 160, height: bar.height)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 36, cornerHeight: 36, transform: nil))
    ctx.setFillColor(color(0xFFFFFF, alpha: bar.alpha))
    ctx.fillPath()
}

// MARK: Coin

let coinCenter = CGPoint(x: 735, y: 285)
let coinRadius: CGFloat = 175

// Drop shadow.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 40, color: color(0x12083A, alpha: 0.55))
ctx.setFillColor(color(0xF5A623))
ctx.fillEllipse(in: CGRect(x: coinCenter.x - coinRadius, y: coinCenter.y - coinRadius,
                           width: coinRadius * 2, height: coinRadius * 2))
ctx.restoreGState()

// Face: gold gradient clipped to the coin.
func clipCircle(radius: CGFloat) {
    ctx.addEllipse(in: CGRect(x: coinCenter.x - radius, y: coinCenter.y - radius,
                              width: radius * 2, height: radius * 2))
    ctx.clip()
}

ctx.saveGState()
clipCircle(radius: coinRadius)
ctx.drawLinearGradient(linearGradient([color(0xFFE27A), color(0xF5A623)]),
                       start: CGPoint(x: coinCenter.x, y: coinCenter.y - coinRadius),
                       end: CGPoint(x: coinCenter.x, y: coinCenter.y + coinRadius), options: [])
ctx.restoreGState()

// Inner rim.
let rimRadius = coinRadius - 26
ctx.setStrokeColor(color(0xD9860F, alpha: 0.85))
ctx.setLineWidth(14)
ctx.strokeEllipse(in: CGRect(x: coinCenter.x - rimRadius, y: coinCenter.y - rimRadius,
                             width: rimRadius * 2, height: rimRadius * 2))

// Up arrow: stem + head.
ctx.setFillColor(color(0xFFFFFF))
let stem = CGRect(x: coinCenter.x - 26, y: coinCenter.y - 20, width: 52, height: 110)
ctx.addPath(CGPath(roundedRect: stem, cornerWidth: 14, cornerHeight: 14, transform: nil))
ctx.fillPath()

let head = CGMutablePath()
head.move(to: CGPoint(x: coinCenter.x, y: coinCenter.y - 105))
head.addLine(to: CGPoint(x: coinCenter.x + 82, y: coinCenter.y - 5))
head.addLine(to: CGPoint(x: coinCenter.x - 82, y: coinCenter.y - 5))
head.closeSubpath()
ctx.addPath(head)
ctx.fillPath()

// MARK: Export

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
