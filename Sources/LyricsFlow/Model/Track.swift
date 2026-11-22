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
    /// Identity of the artwork on screen. The cover dissolve and background cross-fade key on this
    /// rather than `id`, so a new track can keep showing the previous cover until its own arrives.
    let artID: Int

    init(id: Int, title: String, artist: String, album: String, duration: Double,
         cover: NSImage, palette: Palette, lyrics: Lyrics, artID: Int? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.cover = cover
        self.palette = palette
        self.lyrics = lyrics
        self.artID = artID ?? id
    }

    func withLyrics(_ lyrics: Lyrics) -> Track {
        Track(id: id, title: title, artist: artist, album: album, duration: duration,
              cover: cover, palette: palette, lyrics: lyrics, artID: artID)
    }
}
