import SwiftUI

/// Cover art. On a track change the old cover burns away into the new one, ordered by brightness
/// (see `LumaDissolve`), over the same time as the background cross-fade. No scaling or movement.
struct CoverView: View {
    static let duration: TimeInterval = 1.4

    private struct Active {
        let engine: LumaDissolve
        let start: Date
        let token: Int
    }

    let track: Track
    let side: CGFloat

    @State private var current: NSImage
    @State private var active: Active?
    @State private var tokens = 0

    init(track: Track, side: CGFloat) {
        self.track = track
        self.side = side
        _current = State(initialValue: track.cover)
    }

    var body: some View {
        Group {
            if let active {
                TimelineView(.animation) { ctx in
                    let p = min(max(ctx.date.timeIntervalSince(active.start) / Self.duration, 0), 1)
                    let eased = p * p * (3 - 2 * p)
                    if let frame = active.engine.frame(progress: eased) {
                        Image(decorative: frame, scale: 1).resizable().interpolation(.high)
                    } else {
                        Image(nsImage: current).resizable().interpolation(.high)
                    }
                }
            } else {
                Image(nsImage: current).resizable().interpolation(.high)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.03, style: .continuous))
        .shadow(color: .black.opacity(0.32), radius: side * 0.06, y: side * 0.03)
        .onChange(of: track.id) { _, _ in begin() }
    }

    private func begin() {
        let old = current
        current = track.cover
        tokens += 1
        let token = tokens
        guard let engine = LumaDissolve(from: old, to: track.cover, pixels: Int(min(1024, side * 2))) else {
            active = nil
            return
        }
        active = Active(engine: engine, start: Date(), token: token)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.05) {
            if active?.token == token { active = nil }
        }
    }
}

/// Title and "Artist — Album" under the cover. Either line scrolls when it is too long.
struct TitleBlock: View {
    let track: Track
    let width: CGFloat
    let titleSize: CGFloat
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        let align: Alignment = alignment == .leading ? .leading : .center
        VStack(alignment: alignment, spacing: titleSize * 0.2) {
            MarqueeText(text: track.title.isEmpty ? "未知曲目" : track.title,
                        size: titleSize, weight: .semibold, opacity: 0.95, width: width, alignment: align)
                .id(track.id)
            MarqueeText(text: TrackText.subtitle(artist: track.artist, album: track.album),
                        size: titleSize * 0.88, weight: .regular, opacity: 0.68, width: width, alignment: align)
                .id(track.id)
        }
        .frame(width: width, alignment: align)
    }
}
