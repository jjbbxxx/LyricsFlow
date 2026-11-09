import Foundation

/// Exact lookup by artist, title, album and duration. Only synced lyrics are used.
enum LRCLibSource {
    static func lyrics(for meta: TrackMeta) async -> RawLyrics? {
        let js = await HTTPClient.json("https://lrclib.net/api/get",
                                       [("artist_name", meta.artist), ("track_name", meta.title),
                                        ("album_name", meta.album), ("duration", String(Int(meta.duration)))],
                                       headers: ["User-Agent": "LyricsFlow/0.1 (macOS lyrics companion)"])
        let synced = asString(js?["syncedLyrics"])
        return synced.isEmpty ? nil : RawLyrics(lrc: synced)
    }
}
