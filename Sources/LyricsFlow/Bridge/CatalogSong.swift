import Foundation

/// One song record from Apple Music catalog JSON (`amp-api.music.apple.com/v1/catalog/...`).
struct CatalogSong: Equatable {
    let name: String
    let artist: String
    let album: String
    let durationSeconds: Double
    /// Artwork URL template, e.g. `https://is1-ssl.mzstatic.com/.../cover.jpg/{w}x{h}{c}.{f}`.
    let artworkTemplate: String

    /// Everything before `{w}`: every rendered size of this artwork shares this prefix.
    var artworkPrefix: String? {
        guard let r = artworkTemplate.range(of: "{w}") else { return nil }
        let prefix = String(artworkTemplate[..<r.lowerBound])
        return prefix.isEmpty ? nil : prefix
    }

    /// Extracts the song records of a catalog response; anything else yields an empty list.
    static func parse(_ data: Data) -> [CatalogSong] {
        guard let js = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = js["data"] as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard asString(item["type"]) == "songs",
                  let a = item["attributes"] as? [String: Any],
                  let art = a["artwork"] as? [String: Any] else { return nil }
            let template = asString(art["url"])
            guard !template.isEmpty else { return nil }
            return CatalogSong(
                name: asString(a["name"]), artist: asString(a["artistName"]), album: asString(a["albumName"]),
                durationSeconds: asDouble(a["durationInMillis"]) / 1000, artworkTemplate: template
            )
        }
    }
}

/// Picks the catalog record describing the track Music reports over AppleScript.
enum CatalogMatcher {
    private static let durationTolerance = 3.0

    /// `songs` must be ordered newest first; the newest acceptable record wins.
    static func best(_ songs: [CatalogSong], title: String, artist: String, album: String, duration: Double) -> CatalogSong? {
        let wantTitle = TextMatching.normalize(title)
        guard !wantTitle.isEmpty else { return nil }
        return songs.first { s in
            TextMatching.normalize(s.name) == wantTitle
                && artistMatches(s.artist, artist)
                && albumMatches(s.album, album)
                && durationMatches(s.durationSeconds, duration)
        }
    }

    private static func artistMatches(_ a: String, _ b: String) -> Bool {
        let x = TextMatching.normalize(a), y = TextMatching.normalize(b)
        if x.isEmpty || y.isEmpty { return true }
        return x == y || x.contains(y) || y.contains(x)
    }

    private static func albumMatches(_ a: String, _ b: String) -> Bool {
        let x = TextMatching.normalize(a), y = TextMatching.normalize(b)
        return x.isEmpty || y.isEmpty || x == y
    }

    private static func durationMatches(_ a: Double, _ b: Double) -> Bool {
        a <= 0 || b <= 0 || abs(a - b) <= durationTolerance
    }
}
