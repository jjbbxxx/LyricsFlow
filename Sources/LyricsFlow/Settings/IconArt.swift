import AppKit
import SwiftUI

/// Runtime renderer for the "follow the cover" Dock icon. Mirrors the drawing in scripts/make_icon.swift
/// (squircle, diagonal gradient, three lyric bars with a swept highlight), but takes its colours from
/// the current cover palette.
enum IconArt {
    struct RGB { var r: Double, g: Double, b: Double }

    /// The default (aurora) colours, shown when nothing is playing.
    static let fallback: [RGB] = [RGB(r: 0.16, g: 0.13, b: 0.42), RGB(r: 0.49, g: 0.27, b: 0.66), RGB(r: 0.95, g: 0.45, b: 0.56)]

    /// Three gradient stops, dark to light, from the cover palette. Saturation is lifted a little, and
    /// brightness kept in a band where the white lyric bars stay visible.
    static func stops(from palette: Palette) -> [RGB] {
        let colors: [(rgb: RGB, brightness: Double)] = palette.colors.prefix(4).compactMap { color in
            guard let c = NSColor(color).usingColorSpace(.sRGB) else { return nil }
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let bright = min(max(b, 0.35), 0.8)
            let out = NSColor(hue: h, saturation: min(s * 1.25, 1), brightness: bright, alpha: 1)
            return (RGB(r: out.redComponent, g: out.greenComponent, b: out.blueComponent), Double(bright))
        }.sorted { $0.brightness < $1.brightness }
        guard let first = colors.first, let last = colors.last else { return fallback }
        return [first.rgb, colors[colors.count / 2].rgb, last.rgb]
    }

    static func mix(_ a: [RGB], _ b: [RGB], _ t: Double) -> [RGB] {
        zip(a, b).map { RGB(r: $0.r + ($1.r - $0.r) * t, g: $0.g + ($1.g - $0.g) * t, b: $0.b + ($1.b - $0.b) * t) }
    }

    static func image(stops: [RGB], size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.scaleBy(x: size / 1024, y: size / 1024)
            draw(stops: stops, into: ctx)
            return true
        }
    }

    private static func draw(stops: [RGB], into ctx: CGContext) {
        let space = CGColorSpaceCreateDeviceRGB()
        let body = CGRect(x: 100, y: 100, width: 824, height: 824)
        let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
        ctx.addPath(squircle)
        ctx.setFillColor(CGColor(gray: 0.2, alpha: 1))
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(squircle)
        ctx.clip()
        let cg = stops.map { CGColor(red: $0.r, green: $0.g, blue: $0.b, alpha: 1) }
        let bg = CGGradient(colorsSpace: space, colors: cg as CFArray, locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(bg, start: CGPoint(x: 160, y: 924), end: CGPoint(x: 864, y: 100), options: [])

        let glow = CGGradient(colorsSpace: space, colors: [CGColor(gray: 1, alpha: 0.24), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 420, y: 512), startRadius: 0,
                               endCenter: CGPoint(x: 420, y: 512), endRadius: 440, options: [])

        let x: CGFloat = 190
        func bar(_ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
            CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
        }
        for (y, w, h) in [(CGFloat(640), CGFloat(640), CGFloat(92)), (CGFloat(292), CGFloat(560), CGFloat(92))] {
            ctx.addPath(bar(y, w, h))
            ctx.setFillColor(CGColor(gray: 1, alpha: 0.40))
            ctx.fillPath()
        }
        let active = bar(454, 640, 116)
        ctx.addPath(active)
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.48))
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(active)
        ctx.clip()
        let sweep = CGGradient(colorsSpace: space,
                               colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray,
                               locations: [0, 0.62, 1])!
        ctx.drawLinearGradient(sweep, start: CGPoint(x: x, y: 0), end: CGPoint(x: x + 400, y: 0), options: [])
        ctx.restoreGState()

        let sheen = CGGradient(colorsSpace: space, colors: [CGColor(gray: 1, alpha: 0.16), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 640), options: [])
        ctx.restoreGState()

        ctx.addPath(squircle)
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.14))
        ctx.setLineWidth(3)
        ctx.strokePath()
    }
}
