import Foundation

struct Candidate {
    let title: String
    let artist: String
    let duration: Double
    let source: String
    /// Source-specific handle used to fetch the lyric (song id, mid or hash).
    let ref: String
    /// Present when the search response already carries the lyric (LRCLIB).
    var inlineLyrics: String? = nil
}

/// Port of lyrics.py `_variants` / `_score` / `_dur_ok`.
enum LyricsMatcher {
    static let minimumScore = 0.55
    /// A candidate this good ends the query-variant loop early, which keeps request volume low.
    static let confidentScore = 0.92
    private static let brackets = try! NSRegularExpression(pattern: "[\\(\\[（【].*?[\\)\\]）】]")

    static func variants(title: String, artist: String) -> [String] {
        var out: [String] = []
        func add(_ q: String) {
            let t = q.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty, !out.contains(t) { out.append(t) }
        }
        let range = NSRange(title.startIndex..., in: title)
        let noParen = brackets.stringByReplacingMatches(in: title, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespaces)
        add("\(title) \(artist)")
        add("\(noParen) \(artist)")
        let simple = TextMatching.simplified(title)
        if simple != title {
            add("\(simple) \(artist)")
            add(simple)
        }
        add(title)
        return out
    }

    static func score(_ c: Candidate, _ meta: TrackMeta) -> Double {
        let nt = TextMatching.similarity(TextMatching.normalize(c.title), TextMatching.normalize(meta.title))
        let na = TextMatching.similarity(TextMatching.normalize(c.artist), TextMatching.normalize(meta.artist))
        let dd = (meta.duration > 0 && c.duration > 0) ? max(0, 1 - abs(c.duration - meta.duration) / 12) : 0.5
        return nt * 0.55 + dd * 0.30 + na * 0.15
    }

    /// The last line's start time is a cheap check against live and extended versions.
    static func durationOK(lastLineStart: Double, duration: Double) -> Bool {
        guard duration > 0 else { return true }
        return duration * 0.4 <= lastLineStart && lastLineStart <= duration + 25
    }

    /// First highest score wins, like Python's `max`.
    static func best(_ candidates: [Candidate], for meta: TrackMeta) -> (Candidate, Double)? {
        var result: (Candidate, Double)?
        for c in candidates {
            let s = score(c, meta)
            if result == nil || s > result!.1 { result = (c, s) }
        }
        return result
    }
}
