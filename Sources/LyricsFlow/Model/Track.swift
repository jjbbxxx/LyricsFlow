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
}
