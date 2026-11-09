import Foundation

/// NetEase word-level lyrics. Line: `[startMs,durMs](wordStartMs,wordDurMs,0)word ...`.
/// Word timestamps are kept exactly as delivered.
enum YRCParser {
    private static let lineHead = try! NSRegularExpression(pattern: "^\\[(\\d+),(\\d+)\\]")
    private static let wordHead = try! NSRegularExpression(pattern: "\\((\\d+),(\\d+),-?\\d+\\)")

    static func parse(_ text: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for raw in text.split(whereSeparator: \.isNewline).map(String.init) {
            guard let line = parseLine(raw, id: lines.count) else { continue }
            lines.append(line)
        }
        return lines
    }

    private static func parseLine(_ raw: String, id: Int) -> LyricLine? {
        let full = NSRange(raw.startIndex..., in: raw)
        guard let head = lineHead.firstMatch(in: raw, range: full),
              let lineStart = number(raw, head, 1), let lineDur = number(raw, head, 2) else { return nil }
        let bodyStart = head.range.location + head.range.length
        let body = NSRange(location: bodyStart, length: full.length - bodyStart)
        let heads = wordHead.matches(in: raw, range: body)
        let ns = raw as NSString

        var words: [LyricWord] = []
        for (i, m) in heads.enumerated() {
            guard let ws = number(raw, m, 1), let wd = number(raw, m, 2) else { continue }
            let textStart = m.range.location + m.range.length
            let textEnd = i + 1 < heads.count ? heads[i + 1].range.location : ns.length
            let piece = ns.substring(with: NSRange(location: textStart, length: textEnd - textStart))
            if piece.trimmingCharacters(in: .whitespaces).isEmpty {
                // Pure spacing belongs to the previous word.
                if let last = words.popLast() {
                    words.append(LyricWord(text: last.text + piece, start: last.start, end: last.end))
                }
                continue
            }
            words.append(LyricWord(text: piece, start: ws / 1000, end: (ws + wd) / 1000))
        }

        guard !words.isEmpty else {
            // No word timing on this line: keep it as a plain timed line.
            let content = ns.substring(from: bodyStart).trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty, !MetaFilter.isMeta(content) else { return nil }
            return LyricLine(id: id, start: lineStart / 1000, end: (lineStart + lineDur) / 1000, text: content)
        }
        if let first = words.first {
            words[0] = LyricWord(text: String(first.text.drop(while: { $0.isWhitespace })), start: first.start, end: first.end)
        }
        if let last = words.last {
            let trimmed = last.text.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
            words[words.count - 1] = LyricWord(text: trimmed, start: last.start, end: last.end)
        }
        words.removeAll { $0.text.isEmpty }
        guard !words.isEmpty else { return nil }
        let joined = words.map(\.text).joined()
        guard !MetaFilter.isMeta(joined) else { return nil }
        return LyricLine(id: id, words: words)
    }

    private static func number(_ s: String, _ m: NSTextCheckingResult, _ g: Int) -> Double? {
        Range(m.range(at: g), in: s).flatMap { Double(s[$0]) }
    }
}
