import SwiftUI

/// Every line uses the same view structure; only what is drawn changes. Swapping view types when a
/// line becomes current would make SwiftUI treat it as a new view and skip its scroll animation.
struct LyricLineView: View {
    @EnvironmentObject var player: PlaybackModel
    let layout: TextLayout
    let sweep: Bool
    let baseAlpha: CGFloat

    var body: some View {
        TimelineView(.animation(paused: !(sweep && player.isPlaying))) { ctx in
            Canvas { context, _ in
                let mode: LineDrawMode = sweep
                    ? .sweep(time: player.lyricTime(at: ctx.date), baseAlpha: baseAlpha)
                    : .plain
                context.withCGContext { cg in layout.draw(in: cg, mode: mode) }
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .id(player.seekEpoch)
    }
}
