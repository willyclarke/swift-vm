#!/usr/bin/env swift
/// Generates the SwiftVM app icon at all required macOS sizes and writes the
/// files into SwiftVM/Assets.xcassets/AppIcon.appiconset/.
/// Run from the project root:  swift scripts/generate-icon.swift
import AppKit
import Foundation

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetDir  = projectRoot
    .appendingPathComponent("SwiftVM/Assets.xcassets/AppIcon.appiconset")

// MARK: - Rendering

func renderBase(pixels: Int = 1024) -> NSImage {
    let sz = CGFloat(pixels)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: NSColorSpaceName.calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: sz, height: sz)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: sz, height: sz)

    // macOS-style rounded corners (~22 % radius)
    NSBezierPath(roundedRect: rect, xRadius: sz * 0.225, yRadius: sz * 0.225).addClip()

    // Background: deep blue → dark purple, top-left to bottom-right
    NSGradient(
        colors: [
            NSColor(srgbRed: 0.05, green: 0.08, blue: 0.24, alpha: 1),
            NSColor(srgbRed: 0.20, green: 0.07, blue: 0.36, alpha: 1),
        ],
        atLocations: [0, 1], colorSpace: NSColorSpace.sRGB)!
        .draw(in: rect, angle: 135)

    // Subtle inner glow at top so the icon pops
    NSGradient(
        colors: [
            NSColor(white: 1.0, alpha: 0.08),
            NSColor(white: 1.0, alpha: 0.00),
        ],
        atLocations: [0, 1], colorSpace: NSColorSpace.sRGB)!
        .draw(in: rect, angle: 270)

    // --- Penguin ---  large, centred, slight downward offset so the apple fits
    let pFont = NSFont.systemFont(ofSize: sz * 0.58)
    let pAS   = NSAttributedString(string: "🐧", attributes: [.font: pFont])
    let pSz   = pAS.size()
    pAS.draw(at: NSPoint(
        x: (sz - pSz.width)  / 2,
        y: (sz - pSz.height) / 2 - sz * 0.04))

    // --- Apple --- smaller, upper-right corner
    let aFont = NSFont.systemFont(ofSize: sz * 0.26)
    let aAS   = NSAttributedString(string: "🍎", attributes: [.font: aFont])
    let aSz   = aAS.size()
    aAS.draw(at: NSPoint(
        x: sz - aSz.width  - sz * 0.055,
        y: sz - aSz.height - sz * 0.045))

    NSGraphicsContext.restoreGraphicsState()

    let image = NSImage(size: NSSize(width: sz, height: sz))
    image.addRepresentation(rep)
    return image
}

func pngData(from image: NSImage, pixels: Int) -> Data {
    let sz = CGFloat(pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: NSColorSpaceName.calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: sz, height: sz)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: sz, height: sz))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!
}

// MARK: - Size table

struct Spec { let file: String; let px: Int; let pt: String; let scale: String }

let specs: [Spec] = [
    Spec(file: "icon_16x16.png",       px: 16,   pt: "16x16",   scale: "1x"),
    Spec(file: "icon_16x16@2x.png",    px: 32,   pt: "16x16",   scale: "2x"),
    Spec(file: "icon_32x32.png",       px: 32,   pt: "32x32",   scale: "1x"),
    Spec(file: "icon_32x32@2x.png",    px: 64,   pt: "32x32",   scale: "2x"),
    Spec(file: "icon_128x128.png",     px: 128,  pt: "128x128", scale: "1x"),
    Spec(file: "icon_128x128@2x.png",  px: 256,  pt: "128x128", scale: "2x"),
    Spec(file: "icon_256x256.png",     px: 256,  pt: "256x256", scale: "1x"),
    Spec(file: "icon_256x256@2x.png",  px: 512,  pt: "256x256", scale: "2x"),
    Spec(file: "icon_512x512.png",     px: 512,  pt: "512x512", scale: "1x"),
    Spec(file: "icon_512x512@2x.png",  px: 1024, pt: "512x512", scale: "2x"),
]

// MARK: - Main

print("Rendering base icon…")
let base = renderBase()

try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

var allOK = true
for s in specs {
    let url = iconsetDir.appendingPathComponent(s.file)
    do {
        try pngData(from: base, pixels: s.px).write(to: url)
        print("  ✓ \(s.file)  (\(s.px)px)")
    } catch {
        print("  ✗ \(s.file): \(error)")
        allOK = false
    }
}

// Write Contents.json
let entries = specs.map { s in """
        {
          "filename" : "\(s.file)",
          "idiom" : "mac",
          "scale" : "\(s.scale)",
          "size" : "\(s.pt)"
        }
""" }.joined(separator: ",\n")

let json = """
{
  "images" : [
\(entries)
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

try! json.write(
    to: iconsetDir.appendingPathComponent("Contents.json"),
    atomically: true, encoding: .utf8)

print(allOK ? "\nDone — rebuild SwiftVM to apply the icon." : "\nFinished with errors.")
