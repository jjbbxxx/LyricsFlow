import SwiftUI

struct CoverView: View {
    let track: Track
    let side: CGFloat

    var body: some View {
        Image(nsImage: track.cover)
            .resizable()
            .interpolation(.high)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.03, style: .continuous))
            .shadow(color: .black.opacity(0.32), radius: side * 0.06, y: side * 0.03)
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
