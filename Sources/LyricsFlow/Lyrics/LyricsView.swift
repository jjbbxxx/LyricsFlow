import SwiftUI

private final class LayoutCache {
    private var key = ""
    private var layouts: [TextLayout] = []

    func layouts(for track: Track, width: CGFloat, fontSize: CGFloat, centered: Bool) -> [TextLayout] {
        let k = "\(track.id)|\(Int(width))|\(Int(fontSize * 10))|\(centered)"
        if k != key {
            layouts = track.lyrics.lines.map {
                TextLayout(line: $0, width: width, fontSize: fontSize, centered: centered)
            }
            key = k
        }
        return layouts
    }
}

enum LyricStyle {
    /// Reference depth curve: opacity max(0.18, 0.59 - 0.09d), blur min(5.3, 1.2 + 1.2(d-1)), scale max(0.95, 1 - 0.007d).
    static func opacity(_ d: Int) -> Double { d == 0 ? 1 : max(0.18, 0.59 - Double(d) * 0.09) }
    static func blur(_ d: Int) -> Double { d == 0 ? 0 : min(5.3, 1.2 + Double(d - 1) * 1.2) }
    static func scale(_ d: Int) -> Double { max(0.95, 1 - Double(d) * 0.007) }
    static let unsungAlpha: CGFloat = 0.46
    /// Extra space between lyric lines, in em; measured from Apple Music (~0.99).
    static let paragraphGap: CGFloat = 0.99
    static let anchor = 0.43
    /// Apple Music moves lines top to bottom in sequence (measured from a screen recording, ~0.04 s apart).
    static func stagger(line i: Int, current: Int) -> Double {
        Double(min(max(i - (current - 1), 0), 8)) * 0.04
    }
    static let scroll = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.85)
}

struct LyricsView: View {
    @EnvironmentObject var player: PlaybackModel
    @EnvironmentObject var settings: AppSettings
    let track: Track
    let fontSize: CGFloat
    let centered: Bool
    @State private var cache = LayoutCache()

    var body: some View {
        GeometryReader { geo in
            if track.lyrics.lines.isEmpty {
                emptyState(geo.size)
            } else {
                content(geo)
            }
        }
    }

    private func emptyState(_ size: CGSize) -> some View {
        Text(player.lyricsPhase == .searching ? "正在搜索歌词…" : "暂无同步歌词")
            .font(.system(size: fontSize * 0.7, weight: .bold))
            .foregroundStyle(.white.opacity(0.35))
            .frame(width: size.width, alignment: centered ? .center : .leading)
            .offset(y: size.height * LyricStyle.anchor - fontSize * 0.5)
    }

    private func content(_ geo: GeometryProxy) -> some View {
        Group {
            let layouts = cache.layouts(for: track, width: geo.size.width, fontSize: fontSize, centered: centered)
            let gap = fontSize * LyricStyle.paragraphGap
            let idx = player.currentIndex
            let anchor = min(max(idx, 0), max(layouts.count - 1, 0))
            let tops = Self.tops(layouts, gap: gap)
            let shift = geo.size.height * LyricStyle.anchor - (tops[anchor] + layouts[anchor].size.height / 2)
            let animation: Animation? = player.animateScroll ? LyricStyle.scroll : nil

            ZStack(alignment: .topLeading) {
                ForEach(layouts.indices, id: \.self) { i in
                    let d = min(abs(i - idx), 10)
                    if abs(i - idx) <= 10 {
                        let line = track.lyrics.lines[i]
                        LyricLineView(
                            layout: layouts[i],
                            sweep: d == 0 && line.isWordLevel,
                            baseAlpha: LyricStyle.unsungAlpha
                        )
                        .scaleEffect(LyricStyle.scale(d), anchor: centered ? .center : .leading)
                        .blur(radius: LyricStyle.blur(d) * settings.blurScale)
                        .opacity(LyricStyle.opacity(d))
                        .offset(y: tops[i] + shift)
                        .animation(animation.map { $0.delay(LyricStyle.stagger(line: i, current: idx)) }, value: idx)
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .mask(edgeFade)
        }
    }

    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.55), location: 0.12),
                .init(color: .black, location: 0.28),
                .init(color: .black, location: 0.71),
                .init(color: .black.opacity(0.6), location: 0.86),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private static func tops(_ layouts: [TextLayout], gap: CGFloat) -> [CGFloat] {
        var y: CGFloat = 0
        return layouts.map { l in defer { y += l.size.height + gap }; return y }
    }
}
