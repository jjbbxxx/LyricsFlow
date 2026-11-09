import AppKit
import CoreText

struct LayoutLine {
    let ct: CTLine
    let range: Range<Int>
    let x: CGFloat
    let top: CGFloat
    let baseline: CGFloat
    let width: CGFloat
}

/// One word (or the part of a word that falls on one visual line) with its real time span.
struct SweepSegment {
    let x0: CGFloat
    let x1: CGFloat
    let t0: Double
    let t1: Double
}

/// CoreText layout shared by static and sweep drawing so both render pixel-identical glyphs.
final class TextLayout {
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let size: CGSize
    let lines: [LayoutLine]
    let segments: [[SweepSegment]]

    /// Matched to Apple Music lyrics (SF bold; CJK falls back to PingFang SC semibold).
    static let lyricWeight: NSFont.Weight = .bold

    static func font(size: CGFloat) -> CTFont {
        NSFont.systemFont(ofSize: size, weight: lyricWeight) as CTFont
    }

    init(line: LyricLine, width: CGFloat, fontSize: CGFloat, centered: Bool) {
        self.fontSize = fontSize
        let font = Self.font(size: fontSize)
        let lh = (fontSize * 1.19).rounded()
        lineHeight = lh
        let asc = CTFontGetAscent(font), desc = CTFontGetDescent(font)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            NSAttributedString.Key(rawValue: kCTForegroundColorFromContextAttributeName as String): true,
        ]
        let attributed = NSAttributedString(string: line.text, attributes: attrs)
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        let length = attributed.length

        var built: [LayoutLine] = []
        var start = 0
        while start < length {
            var count = CTTypesetterSuggestLineBreak(typesetter, start, Double(max(width, 1)))
            if count <= 0 { count = 1 }
            let ct = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))
            let full = CGFloat(CTLineGetTypographicBounds(ct, nil, nil, nil))
            let w = max(full - CGFloat(CTLineGetTrailingWhitespaceWidth(ct)), 0)
            let top = CGFloat(built.count) * lh
            built.append(LayoutLine(
                ct: ct,
                range: start..<(start + count),
                x: centered ? (width - w) / 2 : 0,
                top: top,
                baseline: top + (lh - (asc + desc)) / 2 + asc,
                width: w
            ))
            start += count
        }
        lines = built
        size = CGSize(width: width, height: CGFloat(max(built.count, 1)) * lh)
        segments = Self.buildSegments(line: line, lines: built)
    }

    private static func buildSegments(line: LyricLine, lines: [LayoutLine]) -> [[SweepSegment]] {
        var result = Array(repeating: [SweepSegment](), count: lines.count)
        guard let words = line.words else { return result }
        for (wi, word) in words.enumerated() {
            let range = line.wordRanges[wi]
            var parts: [(Int, CGFloat, CGFloat)] = []
            for (li, l) in lines.enumerated() {
                let lo = max(range.lowerBound, l.range.lowerBound)
                let hi = min(range.upperBound, l.range.upperBound)
                guard lo < hi else { continue }
                let a = l.x + CGFloat(CTLineGetOffsetForStringIndex(l.ct, lo, nil))
                let b = min(l.x + CGFloat(CTLineGetOffsetForStringIndex(l.ct, hi, nil)), l.x + l.width)
                if b > a { parts.append((li, a, b)) }
            }
            let total = parts.reduce(CGFloat(0)) { $0 + ($1.2 - $1.1) }
            guard total > 0 else { continue }
            var acc: CGFloat = 0
            for (li, a, b) in parts {
                let t0 = word.start + (word.end - word.start) * Double(acc / total)
                acc += b - a
                let t1 = word.start + (word.end - word.start) * Double(acc / total)
                result[li].append(SweepSegment(x0: a, x1: b, t0: t0, t1: t1))
            }
        }
        return result
    }
}
