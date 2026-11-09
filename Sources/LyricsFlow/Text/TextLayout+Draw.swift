import AppKit
import CoreText

enum LineDrawMode {
    /// Solid white; per-line opacity comes from the view modifiers.
    case plain
    /// Real word-level sweep: unsung text at baseAlpha, sung text pure white, soft leading edge.
    case sweep(time: Double, baseAlpha: CGFloat)
}

extension TextLayout {
    /// Soft leading edge width of the sweep, in points.
    static let sweepEdge: CGFloat = 9

    func draw(in cg: CGContext, mode: LineDrawMode) {
        cg.saveGState()
        cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        switch mode {
        case .plain:
            cg.setFillColor(CGColor(gray: 1, alpha: 1))
            lines.forEach { drawLine($0, in: cg) }
        case let .sweep(time, baseAlpha):
            for (k, line) in lines.enumerated() {
                cg.setFillColor(CGColor(gray: 1, alpha: baseAlpha))
                drawLine(line, in: cg)
                drawSung(lineIndex: k, time: time, in: cg)
            }
        }
        cg.restoreGState()
    }

    private func drawLine(_ l: LayoutLine, in cg: CGContext) {
        cg.textPosition = CGPoint(x: l.x, y: l.baseline)
        CTLineDraw(l.ct, cg)
    }

    private func drawSung(lineIndex k: Int, time t: Double, in cg: CGContext) {
        let line = lines[k]
        let segs = segments[k]
        guard !segs.isEmpty else { return }
        let pad = fontSize * 0.3
        let lh = lineHeight
        let band = { (x0: CGFloat, x1: CGFloat) in
            CGRect(x: x0, y: line.top - lh * 0.15, width: x1 - x0, height: lh * 1.3)
        }

        var doneX: CGFloat? = nil
        var active: (idx: Int, seg: SweepSegment)? = nil
        for (i, s) in segs.enumerated() {
            if t >= s.t1 { doneX = i == segs.count - 1 ? s.x1 + pad : s.x1 }
            else { if t >= s.t0 { active = (i, s) }; break }
        }

        cg.setFillColor(CGColor(gray: 1, alpha: 1))
        if let dx = doneX {
            cg.saveGState()
            cg.clip(to: band(line.x - pad, dx))
            drawLine(line, in: cg)
            cg.restoreGState()
        }
        guard let (i, s) = active else { return }

        let edge = min(TextLayout.sweepEdge, (s.x1 - s.x0) * 0.8)
        let span = s.t1 - s.t0
        let f = span > 0 ? CGFloat(min(max((t - s.t0) / span, 0), 1)) : 1
        let pos = s.x0 + f * ((s.x1 - s.x0) + edge)
        let clipRect = band(i == 0 ? line.x - pad : s.x0, i == segs.count - 1 ? s.x1 + pad : s.x1)

        cg.saveGState()
        cg.clip(to: clipRect)
        cg.beginTransparencyLayer(auxiliaryInfo: nil)
        drawLine(line, in: cg)
        cg.setBlendMode(.destinationIn)
        let space = CGColorSpaceCreateDeviceGray()
        let colors = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            cg.drawLinearGradient(
                g,
                start: CGPoint(x: pos - edge, y: 0),
                end: CGPoint(x: pos, y: 0),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        cg.endTransparencyLayer()
        cg.restoreGState()
    }
}
