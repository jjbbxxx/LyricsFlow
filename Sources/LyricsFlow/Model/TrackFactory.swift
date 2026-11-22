import AppKit

/// Builds renderable tracks from live Apple Music metadata.
enum TrackFactory {
    /// Debug: attach the bundled demo lyrics to live tracks so the sync engine can be checked
    /// against real playback before the lyric search arrives in M3.
    static var attachDemoLyrics = false

    private static var counter = 1000
    private static let lock = NSLock()

    static func nextID() -> Int {
        lock.lock(); defer { lock.unlock() }
        counter += 1
        return counter
    }

    /// With no `cover`, `carryFrom` keeps that track's artwork (same `artID`, so nothing animates);
    /// with neither, the placeholder is used.
    static func make(id: Int, title: String, artist: String, album: String, duration: Double,
                     cover: NSImage?, carryFrom previous: Track? = nil) -> Track {
        let lyrics = attachDemoLyrics ? MockLibrary.demoLyrics() : Lyrics(source: "none", lines: [])
        let display = title.isEmpty ? "未知曲目" : title
        if cover == nil, let previous {
            return Track(id: id, title: display, artist: artist, album: album, duration: duration,
                         cover: previous.cover, palette: previous.palette, lyrics: lyrics, artID: previous.artID)
        }
        let image = cover ?? CoverArt.make(.placeholder)
        return Track(id: id, title: display, artist: artist, album: album, duration: duration,
                     cover: image, palette: PaletteExtractor.extract(from: image), lyrics: lyrics, artID: nextID())
    }
}
