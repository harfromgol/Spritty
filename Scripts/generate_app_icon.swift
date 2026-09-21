#!/usr/bin/env swift
// Erzeugt das App-Icon (Resources/Assets.xcassets/AppIcon.appiconset).
// Aufruf im Projektordner: swift Scripts/generate_app_icon.swift
import AppKit

let outDir = "Resources/Assets.xcassets/AppIcon.appiconset"

/// Zeichnet das Icon auf einer 1024×1024-Fläche, skaliert auf `px` Pixel.
func render(px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)

    // macOS-Raster: 824 pt große Fläche mit 100 pt Rand für den Schatten.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill()
    shape.fill()
    ctx.restoreGState()

    ctx.saveGState()
    shape.addClip()
    let gradient = NSGradient(colors: [
        NSColor(red: 0.10, green: 0.78, blue: 0.62, alpha: 1),
        NSColor(red: 0.04, green: 0.42, blue: 0.62, alpha: 1)
    ])!
    gradient.draw(in: body, angle: -60)
    // Sanfter Glanz im oberen Bereich.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), .clear])!
        .draw(in: CGRect(x: 100, y: 512, width: 824, height: 412), angle: -90)
    ctx.restoreGState()

    // Zapfsäule (SF Symbol) in Weiß, mit leichtem Schatten.
    let config = NSImage.SymbolConfiguration(pointSize: 520, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "fuelpump.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let size = symbol.size
        let target = CGRect(x: 512 - size.width / 2, y: 512 - size.height / 2,
                            width: size.width, height: size.height)
        let tinted = NSImage(size: size, flipped: false) { rect in
            symbol.draw(in: rect)
            NSColor.white.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 20,
                      color: NSColor.black.withAlphaComponent(0.30).cgColor)
        tinted.draw(in: target)
        ctx.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(pt: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
    (256, 1), (256, 2), (512, 1), (512, 2)
]
var images: [[String: String]] = []
for (pt, scale) in sizes {
    let name = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
    try! render(px: pt * scale).write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(pt)x\(pt)"])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: URL(fileURLWithPath: "\(outDir)/Contents.json"))
print("Icon erzeugt in \(outDir)")
