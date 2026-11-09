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

/// Song title and artist under the cover. `scale` is the title font size in points.
struct TitleBlock: View {
    let track: Track
    let width: CGFloat
    let titleSize: CGFloat
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: titleSize * 0.2) {
            Text(track.title)
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
            Text(track.artist)
                .font(.system(size: titleSize * 0.93, weight: .regular))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
        }
        .frame(width: width, alignment: alignment == .leading ? .leading : .center)
    }
}
