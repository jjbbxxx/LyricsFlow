import SwiftUI
import AppKit

struct BackgroundView: View {
    @EnvironmentObject var settings: AppSettings
    let palette: Palette

    private static let anchors: [(Double, Double)] = [(0.18, 0.22), (0.82, 0.28), (0.28, 0.82), (0.78, 0.80), (0.52, 0.50)]
    private static let periods: [Double] = [37, 29, 43, 31, 53]
    private static let radii: [Double] = [0.65, 0.60, 0.70, 0.60, 0.50]

    var body: some View {
        ZStack {
            if let base = palette.base {
                Image(decorative: base, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .saturation(1.05)
                    .blur(radius: 70)
                    .scaleEffect(1.4)
            }
            blobs
            Color.black.opacity(palette.darken)
        }
        .clipped()
    }

    private var blobs: some View {
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let amp = reduce ? 0 : settings.motion
        return TimelineView(.animation(minimumInterval: 1.0 / 30, paused: amp == 0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { gc, size in
                let m = max(size.width, size.height)
                for (i, color) in palette.colors.enumerated() where i < Self.anchors.count {
                    let a = Self.anchors[i], p = Self.periods[i]
                    let ph = Double(i) * 1.7
                    let cx = (a.0 + 0.16 * amp * sin(t / p * 2 * .pi + ph)) * size.width
                    let cy = (a.1 + 0.16 * amp * cos(t / (p * 1.3) * 2 * .pi + ph)) * size.height
                    let grad = Gradient(colors: [color.opacity(0.80), color.opacity(0)])
                    gc.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .radialGradient(grad, center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: m * Self.radii[i])
                    )
                }
            }
        }
    }
}
