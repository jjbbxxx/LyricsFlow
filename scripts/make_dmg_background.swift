// Draws the installer window background: swift scripts/make_dmg_background.swift build/dmg-bg.png
// 660x440 pt at 2x. A mid-tone background keeps Finder's own icon labels readable in light and dark mode.
import AppKit

let w: CGFloat = 660, h: CGFloat = 440, scale: CGFloat = 2

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * scale), pixelsHigh: Int(h * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: w, height: h)   // 144 dpi, so Finder shows it at 660x440 pt
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
// Flip to top-left origin so coordinates match the layout notes below.
ctx.translateBy(x: 0, y: h)
ctx.scaleBy(x: 1, y: -1)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(red: r, green: g, blue: b, alpha: a) }

let space = CGColorSpaceCreateDeviceRGB()
let bg = CGGradient(colorsSpace: space,
                    colors: [rgb(0.40, 0.34, 0.74).cgColor, rgb(0.62, 0.38, 0.70).cgColor, rgb(0.82, 0.47, 0.62).cgColor] as CFArray,
                    locations: [0, 0.6, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: h), options: [])

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, centerY: CGFloat, mono: Bool = false) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 3
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor.white.withAlphaComponent(alpha), .shadow: shadow,
    ]
    let str = NSAttributedString(string: s, attributes: attrs)
    let sz = str.size()
    // Draw un-flipped text inside the flipped context.
    ctx.saveGState()
    ctx.translateBy(x: (w - sz.width) / 2, y: centerY + sz.height / 2)
    ctx.scaleBy(x: 1, y: -1)
    str.draw(at: .zero)
    ctx.restoreGState()
}

text("把 LyricsFlow 拖到「应用程序」文件夹", size: 22, weight: .semibold, alpha: 0.97, centerY: 56)

// Arrow between the two icon slots (app at x=170, Applications at x=490, both at y=185).
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
ctx.setLineWidth(5)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: 262, y: 185)); ctx.addLine(to: CGPoint(x: 398, y: 185))
ctx.move(to: CGPoint(x: 376, y: 163)); ctx.addLine(to: CGPoint(x: 400, y: 185)); ctx.addLine(to: CGPoint(x: 376, y: 207))
ctx.strokePath()

// Help block.
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
ctx.setLineWidth(1)
ctx.move(to: CGPoint(x: 60, y: 300)); ctx.addLine(to: CGPoint(x: w - 60, y: 300)); ctx.strokePath()

text("第一次打开如果提示“无法打开”或“已损坏”", size: 14, weight: .semibold, alpha: 0.95, centerY: 332)
text("系统设置 → 隐私与安全性 → 拉到最下面，点「仍要打开」", size: 13, weight: .regular, alpha: 0.9, centerY: 360)
text("或在终端运行：", size: 12, weight: .regular, alpha: 0.8, centerY: 385)
text("xattr -dr com.apple.quarantine /Applications/LyricsFlow.app", size: 11.5, weight: .medium, alpha: 0.95, centerY: 408, mono: true)

try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/dmg-bg.png"))
