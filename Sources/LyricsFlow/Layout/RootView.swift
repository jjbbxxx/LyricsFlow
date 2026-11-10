import SwiftUI

struct RootView: View {
    @EnvironmentObject var player: PlaybackModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        if let track = player.track {
            stage(track)
        } else {
            IdleView(status: player.status)
        }
    }

    private func stage(_ track: Track) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let portrait = isPortrait(w, h)
            ZStack {
                ZStack {
                    BackgroundView(palette: track.palette)
                        .id(track.id)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.animation(.linear(duration: 0.01).delay(1.5))
                        ))
                }
                .animation(.easeInOut(duration: 1.4), value: track.id)

                Group {
                    if portrait { PortraitLayout(track: track, size: geo.size) }
                    else { LandscapeLayout(track: track, size: geo.size) }
                }
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .background(Color.black)
    }

    private func isPortrait(_ w: CGFloat, _ h: CGFloat) -> Bool {
        switch settings.effectiveLayout {
        case .auto: return w < h * 1.05
        case .landscape: return false
        case .portrait: return true
        }
    }
}

/// Geometry measured from Apple Music's mini-player lyrics view (window 1920x1050pt).
struct LandscapeLayout: View {
    @EnvironmentObject var settings: AppSettings
    let track: Track
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        let side = min(w * 0.28, h * 0.5)
        let font = min(w * 0.026, h * 0.0475) * settings.lyricScale
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: h * 0.021) {
                CoverView(track: track, side: side)
                Fading(trackID: track.id) { TitleBlock(track: track, width: side, titleSize: max(w * 0.0105, 13)) }
            }
            .offset(x: w * 0.11, y: h * 0.169)

            Fading(trackID: track.id) { LyricsView(track: track, fontSize: font, centered: false) }
                .frame(width: w * 0.455, height: h)
                .offset(x: w * 0.511)
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }
}

struct PortraitLayout: View {
    @EnvironmentObject var settings: AppSettings
    let track: Track
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        let side = min(w * 0.80, h * 0.40)
        let top = h * 0.07
        let header = side + side * 0.07 + side * 0.17
        let lyricsH = max(h - top - header - h * 0.01, 100)
        let font = min(w * 0.05, lyricsH * 0.11) * settings.lyricScale
        VStack(spacing: 0) {
            VStack(spacing: side * 0.07) {
                CoverView(track: track, side: side)
                Fading(trackID: track.id) { TitleBlock(track: track, width: side, titleSize: side * 0.05, alignment: .center) }
            }
            .padding(.top, top)
            Fading(trackID: track.id) { LyricsView(track: track, fontSize: font, centered: false) }
                .frame(width: side, height: lyricsH)
                .padding(.top, h * 0.01)
        }
        .frame(width: w, height: h, alignment: .top)
    }
}

/// Swaps its content when the track changes: the old content leaves quickly, the new one arrives a
/// beat later, so the two never read as overlapping text. They share a ZStack, so the layout holds still.
struct Fading<Content: View>: View {
    let trackID: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            content().id(trackID).transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.45).delay(0.22)),
                removal: .opacity.animation(.easeIn(duration: 0.2))
            ))
        }
        .animation(.easeInOut(duration: 0.5), value: trackID)
    }
}
