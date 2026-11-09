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

    static func make(id: Int, title: String, artist: String, album: String, duration: Double, cover: NSImage?) -> Track {
        let image = cover ?? CoverArt.make(.placeholder)
        let lyrics = attachDemoLyrics ? MockLibrary.demoLyrics() : Lyrics(source: "none", lines: [])
        return Track(
            id: id,
            title: title.isEmpty ? "未知曲目" : title,
            artist: artist, album: album, duration: duration,
            cover: image, palette: PaletteExtractor.extract(from: image), lyrics: lyrics
        )
    }
}
