import Foundation

/// Turns a source's raw payload into the unified model without flattening word-level data.
enum LyricsAssembler {
    static func build(_ raw: RawLyrics, source: String) -> Lyrics? {
        let lrcLines = LRCParser.lines(raw.lrc)
        if let yrc = raw.yrc {
            let wordLines = YRCParser.parse(yrc)
            // A partial YRC (far fewer lines than the LRC) is not trustworthy; fall back to the LRC.
            if !wordLines.isEmpty, wordLines.count * 10 >= lrcLines.count * 6 {
                return Lyrics(source: source, lines: wordLines)
            }
        }
        return lrcLines.isEmpty ? nil : Lyrics(source: source, lines: lrcLines)
    }
}
