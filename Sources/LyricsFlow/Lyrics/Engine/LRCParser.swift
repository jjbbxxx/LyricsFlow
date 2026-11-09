import Foundation

enum LRCParser {
    private static let stamp = try! NSRegularExpression(pattern: "\\[(\\d+):(\\d+(?:\\.\\d+)?)\\]")

    /// Time-ordered (seconds, text); credit and empty lines removed.
    static func parse(_ text: String) -> [(Double, String)] {
        var out: [(Double, String)] = []
        for raw in text.split(whereSeparator: \.isNewline).map(String.init) {
            let range = NSRange(raw.startIndex..., in: raw)
            let stamps = stamp.matches(in: raw, range: range)
            guard !stamps.isEmpty else { continue }
            let content = stamp.stringByReplacingMatches(in: raw, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty, !MetaFilter.isMeta(content) else { continue }
            for m in stamps {
                guard let mm = Range(m.range(at: 1), in: raw).flatMap({ Double(raw[$0]) }),
                      let ss = Range(m.range(at: 2), in: raw).flatMap({ Double(raw[$0]) }) else { continue }
                out.append((mm * 60 + ss, content))
            }
        }
        return out.sorted { $0.0 < $1.0 }
    }

    static func lines(_ text: String) -> [LyricLine] { LyricBuilder.lrc(parse(text)) }
}
