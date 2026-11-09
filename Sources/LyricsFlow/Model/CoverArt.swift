import AppKit

/// Procedural placeholder covers covering the colour cases the background engine must handle.
enum CoverArt {
    enum Kind { case blue, gold, mono, pale, placeholder }

    static func make(_ kind: Kind, side: CGFloat = 720) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            switch kind {
            case .blue: drawBlue(cg, rect)
            case .gold: drawGold(cg, rect)
            case .mono: drawMono(cg, rect)
            case .pale: drawPale(cg, rect)
            case .placeholder: gradient(cg, rect, [(0.30, 0.31, 0.34), (0.16, 0.17, 0.19)])
            }
            return true
        }
    }

    private static func gradient(_ cg: CGContext, _ rect: CGRect, _ colors: [(CGFloat, CGFloat, CGFloat)]) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let cols = colors.map { CGColor(red: $0.0, green: $0.1, blue: $0.2, alpha: 1) } as CFArray
        guard let g = CGGradient(colorsSpace: cs, colors: cols, locations: nil) else { return }
        cg.drawLinearGradient(g, start: CGPoint(x: 0, y: rect.height), end: CGPoint(x: rect.width, y: 0), options: [])
    }

    private static func ring(_ cg: CGContext, _ r: CGRect, _ gray: CGFloat, _ alpha: CGFloat) {
        cg.setFillColor(CGColor(gray: gray, alpha: alpha))
        cg.fillEllipse(in: r)
    }

    private static func label(_ text: String, at p: CGPoint, size: CGFloat, color: NSColor, kern: CGFloat) {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .heavy),
            .foregroundColor: color,
            .kern: kern,
        ]).draw(at: p)
    }

    private static func drawBlue(_ cg: CGContext, _ r: CGRect) {
        gradient(cg, r, [(0.78, 0.86, 0.91), (0.55, 0.65, 0.78), (0.22, 0.30, 0.46)])
        ring(cg, CGRect(x: r.width * 0.30, y: r.height * 0.1, width: r.width * 0.40, height: r.height * 0.8), 1, 0.10)
        ring(cg, CGRect(x: r.width * 0.37, y: r.height * 0.2, width: r.width * 0.26, height: r.height * 0.6), 1, 0.12)
        label("ECHOES", at: CGPoint(x: r.width * 0.12, y: r.height * 0.13), size: r.width * 0.075, color: .white, kern: r.width * 0.02)
    }

    private static func drawGold(_ cg: CGContext, _ r: CGRect) {
        gradient(cg, r, [(0.97, 0.80, 0.36), (0.78, 0.50, 0.14), (0.24, 0.13, 0.06)])
        ring(cg, CGRect(x: r.width * 0.22, y: r.height * 0.30, width: r.width * 0.56, height: r.width * 0.56), 1.0, 0.0)
        cg.setFillColor(CGColor(red: 1, green: 0.88, blue: 0.55, alpha: 0.92))
        cg.fillEllipse(in: CGRect(x: r.width * 0.28, y: r.height * 0.36, width: r.width * 0.44, height: r.width * 0.44))
        cg.setFillColor(CGColor(red: 0.18, green: 0.09, blue: 0.04, alpha: 0.85))
        cg.fill(CGRect(x: 0, y: 0, width: r.width, height: r.height * 0.28))
        label("夜航", at: CGPoint(x: r.width * 0.08, y: r.height * 0.08), size: r.width * 0.11, color: NSColor(red: 1, green: 0.85, blue: 0.5, alpha: 1), kern: r.width * 0.02)
    }

    private static func drawMono(_ cg: CGContext, _ r: CGRect) {
        cg.setFillColor(CGColor(gray: 0.04, alpha: 1))
        cg.fill(r)
        for i in 0..<7 {
            let s = r.width * (0.9 - CGFloat(i) * 0.12)
            let rect = CGRect(x: (r.width - s) / 2, y: (r.height - s) / 2, width: s, height: s)
            ring(cg, rect, i % 2 == 0 ? 0.92 : 0.06, 1)
        }
        label("STATIC", at: CGPoint(x: r.width * 0.06, y: r.height * 0.05), size: r.width * 0.07, color: .white, kern: r.width * 0.02)
    }

    private static func drawPale(_ cg: CGContext, _ r: CGRect) {
        gradient(cg, r, [(0.99, 0.99, 0.98), (0.95, 0.96, 0.96), (0.90, 0.92, 0.94)])
        ring(cg, CGRect(x: r.width * 0.2, y: r.height * 0.25, width: r.width * 0.6, height: r.width * 0.6), 0.86, 0.5)
        ring(cg, CGRect(x: r.width * 0.35, y: r.height * 0.4, width: r.width * 0.3, height: r.width * 0.3), 1, 0.8)
        label("PAPER SKY", at: CGPoint(x: r.width * 0.08, y: r.height * 0.07), size: r.width * 0.06, color: NSColor(white: 0.45, alpha: 1), kern: r.width * 0.015)
    }
}
