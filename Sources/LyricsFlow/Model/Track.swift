import AppKit

struct Track: Identifiable {
    let id: Int
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let cover: NSImage
    let palette: Palette
    let lyrics: Lyrics

    func withLyrics(_ lyrics: Lyrics) -> Track {
        Track(id: id, title: title, artist: artist, album: album, duration: duration,
              cover: cover, palette: palette, lyrics: lyrics)
    }
}
