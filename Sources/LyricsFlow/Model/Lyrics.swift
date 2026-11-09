import Foundation

enum SyncPrecision { case word, line, plain }

struct LyricWord: Hashable, Codable {
    let text: String
    let start: Double
    let end: Double
}

struct LyricLine: Identifiable, Hashable, Codable {
    let id: Int
    let start: Double
    let end: Double
    let text: String
    /// Source-provided per-word timing. nil when the source only has line timestamps.
    let words: [LyricWord]?
    /// UTF-16 ranges of each word inside `text`; contiguous so spaces belong to the preceding word.
    let wordRanges: [Range<Int>]

    init(id: Int, start: Double, end: Double, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
        self.words = nil
        self.wordRanges = []
    }

    init(id: Int, words: [LyricWord]) {
        precondition(!words.isEmpty)
        self.id = id
        self.start = words[0].start
        self.end = words[words.count - 1].end
        self.text = words.map(\.text).joined()
        self.words = words
        var cursor = 0
        self.wordRanges = words.map { w in
            let r = cursor..<(cursor + w.text.utf16.count)
            cursor = r.upperBound
            return r
        }
    }

    var isWordLevel: Bool { words != nil }
}

struct Lyrics: Codable {
    let source: String
    let lines: [LyricLine]

    var precision: SyncPrecision {
        lines.contains(where: \.isWordLevel) ? .word : .line
    }

    /// Index of the last line whose start <= t, or -1 before the first line.
    func index(at t: Double) -> Int {
        var lo = 0, hi = lines.count - 1, ans = -1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lines[mid].start <= t { ans = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        return ans
    }
}
