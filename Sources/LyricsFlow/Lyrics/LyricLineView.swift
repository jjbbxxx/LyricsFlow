import SwiftUI

struct LyricLineView: View {
    @EnvironmentObject var player: MockPlayer
    let layout: TextLayout
    let sweep: Bool
    let baseAlpha: CGFloat

    var body: some View {
        if sweep {
            TimelineView(.animation(paused: !player.isPlaying)) { ctx in
                canvas(.sweep(time: player.lyricTime(at: ctx.date), baseAlpha: baseAlpha))
            }
            .id(player.seekEpoch)
        } else {
            canvas(.plain)
        }
    }

    private func canvas(_ mode: LineDrawMode) -> some View {
        Canvas { context, _ in
            context.withCGContext { cg in layout.draw(in: cg, mode: mode) }
        }
        .frame(width: layout.size.width, height: layout.size.height)
    }
}
