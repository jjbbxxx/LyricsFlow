// App icon renderer.
//   swift scripts/make_icon.swift . sheet            -> build/shots/icon_sheet.png (all palettes, for comparing)
//   swift scripts/make_icon.swift . pngs             -> assets/icons/<name>.png (runtime icon choices bundled into the app)
//   swift scripts/make_icon.swift . iconset <name>   -> build/AppIcon.iconset (then iconutil -> assets/AppIcon.icns)
import AppKit

let canvas: CGFloat = 1024

struct Palette {
    let name: String
    let stops: [CGColor]      // background gradient, top-left to bottom-right
    let ink: CGColor          // lyric bars (white on dark backgrounds, dark on light ones)
    let dim: CGFloat          // alpha of inactive bars
    let sheenAlpha: CGFloat
    var softSweep = false     // long eased sweep edge, for the low-contrast black-and-white themes
    var light = false         // light backgrounds need a softer shadow edge and a brighter glow
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: 1) }
let white = CGColor(gray: 1, alpha: 1)

let palettes: [Palette] = [
    Palette(name: "aurora", stops: [rgb(0.16, 0.13, 0.42), rgb(0.49, 0.27, 0.66), rgb(0.95, 0.45, 0.56)], ink: white, dim: 0.40, sheenAlpha: 0.16),
    Palette(name: "ocean", stops: [rgb(0.05, 0.10, 0.30), rgb(0.08, 0.40, 0.62), rgb(0.30, 0.82, 0.82)], ink: white, dim: 0.40, sheenAlpha: 0.16),
    Palette(name: "sunset", stops: [rgb(0.30, 0.08, 0.30), rgb(0.88, 0.27, 0.35), rgb(1.00, 0.70, 0.30)], ink: white, dim: 0.42, sheenAlpha: 0.16),
    // Classic Apple Music red (#FB5C74 to #FA233B), light at the top.
    Palette(name: "music-red", stops: [rgb(0.984, 0.361, 0.455), rgb(0.976, 0.251, 0.353), rgb(0.980, 0.137, 0.231)], ink: white, dim: 0.42, sheenAlpha: 0.14),
    // Apple Music's 2026 black-and-white identity (light and dark appearance).
    Palette(name: "mono-light", stops: [rgb(1, 1, 1), rgb(0.97, 0.97, 0.98), rgb(0.91, 0.91, 0.93)], ink: rgb(0.04, 0.04, 0.05), dim: 0.13, sheenAlpha: 0.0, softSweep: true, light: true),
    Palette(name: "mono-dark", stops: [rgb(0.0, 0.0, 0.0), rgb(0.05, 0.05, 0.06), rgb(0.13, 0.13, 0.15)], ink: white, dim: 0.28, sheenAlpha: 0.08, softSweep: true),
]

func render(_ p: Palette, into ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    let space = CGColorSpaceCreateDeviceRGB()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(squircle)
    ctx.setFillColor(CGColor(gray: 0.2, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    let bg = CGGradient(colorsSpace: space, colors: p.stops as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 160, y: 924), end: CGPoint(x: 864, y: 100), options: [])

    let glowColor = CGColor(gray: 1, alpha: p.light ? 0.6 : 0.24)
    let glow = CGGradient(colorsSpace: space, colors: [glowColor, glowColor.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 420, y: 512), startRadius: 0,
                           endCenter: CGPoint(x: 420, y: 512), endRadius: 440, options: [])

    // Three lines, left aligned. The outer two are wide; the middle one is the active line.
    let x: CGFloat = 190
    func bar(_ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
    }
    for (y, w, h) in [(CGFloat(640), CGFloat(640), CGFloat(92)), (CGFloat(292), CGFloat(560), CGFloat(92))] {
        ctx.addPath(bar(y, w, h))
        ctx.setFillColor(p.ink.copy(alpha: p.dim)!)
        ctx.fillPath()
    }

    let activeW: CGFloat = 640, activeH: CGFloat = 116, activeY: CGFloat = 454
    let active = bar(activeY, activeW, activeH)
    ctx.addPath(active)
    ctx.setFillColor(p.ink.copy(alpha: p.dim + 0.08)!)
    ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(active)
    ctx.clip()
    // Sweep edge: linear for the colourful themes; a long smoothstep ramp for the monochrome ones.
    let span: CGFloat = p.softSweep ? 560 : 400
    let ramp: [(CGFloat, CGFloat)] = p.softSweep
        ? (0...10).map { i in
            let t = CGFloat(i) / 10, u = max(0, (t - 0.12) / 0.88)
            return (t, 1 - u * u * (3 - 2 * u))
        }
        : [(0, 1), (0.62, 1), (1, 0)]
    let sweep = CGGradient(colorsSpace: space,
                           colors: ramp.map { p.ink.copy(alpha: $0.1)! } as CFArray,
                           locations: ramp.map { $0.0 })!
    ctx.drawLinearGradient(sweep, start: CGPoint(x: x, y: 0), end: CGPoint(x: x + span, y: 0), options: [])
    ctx.restoreGState()

    if p.sheenAlpha > 0 {
        let sheen = CGGradient(colorsSpace: space,
                               colors: [CGColor(gray: 1, alpha: p.sheenAlpha), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 640), options: [])
    }
    ctx.restoreGState()

    ctx.addPath(squircle)
    ctx.setStrokeColor(CGColor(gray: p.light ? 0 : 1, alpha: 0.14))
    ctx.setLineWidth(3)
    ctx.strokePath()
}

func bitmap(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    draw(gc.cgContext)
    return rep
}

func pngData(_ p: Palette, size: Int) -> Data {
    bitmap(size, size) { ctx in
        ctx.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
        render(p, into: ctx)
    }.representation(using: .png, properties: [:])!
}

let args = CommandLine.arguments
let root = URL(fileURLWithPath: args.count > 1 ? args[1] : ".")
let mode = args.count > 2 ? args[2] : "sheet"
let fm = FileManager.default

if mode == "sheet" {
    let cell = 420, cols = 3, rows = 2, label = 40
    let sheet = bitmap(cell * cols, (cell + label) * rows) { ctx in
        ctx.setFillColor(CGColor(gray: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: cell * cols, height: (cell + label) * rows))
        for (i, p) in palettes.enumerated() {
            let col = i % cols, row = rows - 1 - i / cols
            let ox = CGFloat(col * cell), oy = CGFloat(row * (cell + label))
            ctx.saveGState()
            ctx.translateBy(x: ox, y: oy + CGFloat(label))
            ctx.scaleBy(x: CGFloat(cell) / canvas, y: CGFloat(cell) / canvas)
            render(p, into: ctx)
            ctx.restoreGState()
            let text = "\(i + 1). \(p.name)" as NSString
            text.draw(at: CGPoint(x: ox + 20, y: oy + 8),
                      withAttributes: [.font: NSFont.boldSystemFont(ofSize: 22), .foregroundColor: NSColor.white])
        }
    }
    let out = root.appendingPathComponent("build/shots/icon_sheet.png")
    try fm.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
    try sheet.representation(using: .png, properties: [:])!.write(to: out)
    print(out.path)
} else if mode == "pngs" {
    let dir = root.appendingPathComponent("assets/icons")
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    for p in palettes { try pngData(p, size: 1024).write(to: dir.appendingPathComponent("\(p.name).png")) }
    print(dir.path)
} else {
    let name = args.count > 3 ? args[3] : "aurora"
    guard let p = palettes.first(where: { $0.name == name }) else { fatalError("unknown palette \(name)") }
    let set = root.appendingPathComponent("build/AppIcon.iconset")
    try? fm.removeItem(at: set)
    try fm.createDirectory(at: set, withIntermediateDirectories: true)
    for base in [16, 32, 128, 256, 512] {
        try pngData(p, size: base).write(to: set.appendingPathComponent("icon_\(base)x\(base).png"))
        try pngData(p, size: base * 2).write(to: set.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
    }
    print(set.path)
}
