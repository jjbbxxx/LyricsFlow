import Foundation

/// Port of lyrics.py `_norm` / `_sim` / `_t2s`.
enum TextMatching {
    private static let brackets = try! NSRegularExpression(pattern: "[\\(\\[（【].*?[\\)\\]）】]")

    static func simplified(_ s: String) -> String {
        s.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? s
    }

    /// Lower-case, traditional to simplified, drop bracketed text, keep letters and digits only.
    /// (lyrics.py kept only ASCII and CJK; keeping every letter also lets kana and hangul titles match.)
    static func normalize(_ s: String) -> String {
        let lowered = simplified(s.lowercased())
        let range = NSRange(lowered.startIndex..., in: lowered)
        let stripped = brackets.stringByReplacingMatches(in: lowered, range: range, withTemplate: "")
        return String(stripped.unicodeScalars.filter { $0.properties.isAlphabetic || $0.properties.numericType != nil }
            .map(Character.init))
    }

    /// Ratcliff/Obershelp ratio, equal to Python `difflib.SequenceMatcher(None, a, b).ratio()`.
    static func similarity(_ a: String, _ b: String) -> Double {
        let x = Array(a.unicodeScalars), y = Array(b.unicodeScalars)
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        let matches = matchingScalars(x[...], y[...])
        return 2.0 * Double(matches) / Double(x.count + y.count)
    }

    private static func matchingScalars(_ a: ArraySlice<Unicode.Scalar>, _ b: ArraySlice<Unicode.Scalar>) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        // Longest common substring, earliest in `a` then earliest in `b` (difflib tie-break).
        var best = 0, bi = a.startIndex, bj = b.startIndex
        var prev = [Int](repeating: 0, count: b.count + 1)
        for i in a.indices {
            var cur = [Int](repeating: 0, count: b.count + 1)
            for j in b.indices where a[i] == b[j] {
                let k = prev[j - b.startIndex] + 1
                cur[j - b.startIndex + 1] = k
                if k > best { best = k; bi = i - k + 1; bj = j - k + 1 }
            }
            prev = cur
        }
        guard best > 0 else { return 0 }
        return best
            + matchingScalars(a[a.startIndex..<bi], b[b.startIndex..<bj])
            + matchingScalars(a[(bi + best)...], b[(bj + best)...])
    }
}
