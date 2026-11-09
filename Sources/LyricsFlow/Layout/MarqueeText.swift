import SwiftUI
import AppKit

/// Single-line text that scrolls when it does not fit, with soft edges (like Apple Music's title area).
struct MarqueeText: View {
    let text: String
    let size: CGFloat
    let weight: Font.Weight
    let opacity: Double
    let width: CGFloat
    var alignment: Alignment = .leading

    @State private var start = Date()

    private static let fade: CGFloat = 14

    private var nsWeight: NSFont.Weight {
        switch weight {
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        default: return .regular
        }
    }

    private var textWidth: CGFloat {
        ceil(NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size, weight: nsWeight)]).size().width)
    }

    private var label: some View {
        Text(text)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(.white.opacity(opacity))
            .lineLimit(1)
            .fixedSize()
    }

    var body: some View {
        Group {
            if textWidth <= width + 0.5 {
                label.frame(width: width, alignment: alignment)
            } else {
                scrolling
            }
        }
        .frame(height: size * 1.25)
    }

    private var scrolling: some View {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let gap = size * 3
        let period = Double(textWidth + gap)
        let math = MarqueeMath(period: period, pause: MarqueeMath.startPause, duration: MarqueeMath.duration(period: period))
        return TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { ctx in
            let offset = reduceMotion ? 0 : math.offset(elapsed: ctx.date.timeIntervalSince(start))
            HStack(spacing: gap) { label; label }
                .offset(x: CGFloat(offset))
                .frame(width: width, alignment: .leading)
                .mask(edgeMask(leftFade: offset < -0.5))
        }
        .onAppear { start = Date() }
    }

    private func edgeMask(leftFade: Bool) -> some View {
        let f = Self.fade / max(width, 1)
        return LinearGradient(
            stops: [
                .init(color: leftFade ? .clear : .black, location: 0),
                .init(color: .black, location: leftFade ? f : 0),
                .init(color: .black, location: 1 - f),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }
}
