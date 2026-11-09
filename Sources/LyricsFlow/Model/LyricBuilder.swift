import Foundation

/// Compact helpers for hand-written mock lyrics. Format: "word|seconds word|seconds ..."
enum LyricBuilder {
    private static func parse(_ spec: String) -> [(String, Double)] {
        spec.split(separator: " ").map { tok in
            let parts = tok.split(separator: "|")
            return (String(parts[0]), Double(parts[1]) ?? 0.4)
        }
    }

    /// Space-separated language (English): a trailing space is attached to each word but the last.
    static func spaced(id: Int, at start: Double, _ spec: String) -> LyricLine {
        let items = parse(spec)
        var t = start
        let words = items.enumerated().map { i, item -> LyricWord in
            let w = LyricWord(text: i < items.count - 1 ? item.0 + " " : item.0, start: t, end: t + item.1)
            t += item.1
            return w
        }
        return LyricLine(id: id, words: words)
    }

    /// Unspaced language (Chinese): tokens are concatenated as-is.
    static func unspaced(id: Int, at start: Double, _ spec: String) -> LyricLine {
        var t = start
        let words = parse(spec).map { item -> LyricWord in
            let w = LyricWord(text: item.0, start: t, end: t + item.1)
            t += item.1
            return w
        }
        return LyricLine(id: id, words: words)
    }

    /// Line-level (plain LRC): only a start time and text; the end is the next line's start.
    static func lrc(_ entries: [(Double, String)], tail: Double = 3) -> [LyricLine] {
        entries.enumerated().map { i, e in
            let end = i + 1 < entries.count ? entries[i + 1].0 : e.0 + tail
            return LyricLine(id: i, start: e.0, end: end, text: e.1)
        }
    }
}
