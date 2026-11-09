import Foundation

/// LRCLIB: exact lookup by artist, title, album and duration, plus free-text search.
/// Only synced lyrics are used.
struct LRCLibSource: LyricSource {
    let id = "lrclib"
    private static let headers = ["User-Agent": "LyricsFlow/0.1 (macOS lyrics companion)"]

    static func lyrics(for meta: TrackMeta) async -> RawLyrics? {
        let js = await HTTPClient.json("https://lrclib.net/api/get",
                                       [("artist_name", meta.artist), ("track_name", meta.title),
                                        ("album_name", meta.album), ("duration", String(Int(meta.duration)))],
                                       headers: headers)
        let synced = asString(js?["syncedLyrics"])
        return synced.isEmpty ? nil : RawLyrics(lrc: synced)
    }

    func search(_ query: String) async -> [Candidate] {
        let items = await HTTPClient.jsonArray("https://lrclib.net/api/search", [("q", query)], headers: Self.headers)
        return items.compactMap { s in
            let synced = asString(s["syncedLyrics"])
            guard !synced.isEmpty else { return nil }
            return Candidate(title: asString(s["trackName"]), artist: asString(s["artistName"]),
                             duration: asDouble(s["duration"]), source: id, ref: asString(s["id"]), inlineLyrics: synced)
        }
    }

    func fetch(_ c: Candidate) async -> RawLyrics { RawLyrics(lrc: c.inlineLyrics ?? "") }
}
