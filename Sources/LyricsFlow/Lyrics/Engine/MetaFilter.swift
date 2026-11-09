import Foundation

/// Port of lyrics.py `_is_meta`: drops credit lines (lyricist, composer, producer ...).
enum MetaFilter {
    private static let keywords = [
        "作词", "作詞", "作曲", "编曲", "編曲", "收录", "收錄", "演唱", "歌手", "歌曲",
        "制作", "製作", "歌词", "歌詞", "翻译", "翻譯", "插曲", "插入歌",
        "主题歌", "主題歌", "片头曲", "片頭曲", "片尾曲", "监制", "監製", "混音",
        "和声", "和聲", "录音", "錄音", "母带", "母帶", "出品", "发行", "發行",
        "策划", "策劃", "统筹", "統籌", "吉他", "贝斯", "貝斯", "键盘", "鍵盤",
        "SoundTrack", "アニメ", "词", "詞", "曲",
        "Producer", "Written", "Composer", "Lyricist", "Arranger", "Mixed", "Mastered",
    ]
    private static let keywordRE = try! NSRegularExpression(
        pattern: "(?:\(keywords.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")))\\s*[:：]",
        options: [.caseInsensitive])
    private static let englishRE = try! NSRegularExpression(
        pattern: "^\\s*(?:(?:written|produced|composed|arranged|lyrics|music|mixed|mastered|engineered)\\s+by|by|title|song|album|artist|singer|lyrics|composer|arranger|producer|op|ed)\\b\\s*[:：]",
        options: [.caseInsensitive])
    private static let digits8 = try! NSRegularExpression(pattern: "\\b\\d{8}\\b")
    private static let urlLike = try! NSRegularExpression(pattern: "^[\\w./@:\\-]+$")

    static func isMeta(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t == "." { return true }
        let r = NSRange(t.startIndex..., in: t)
        if keywordRE.firstMatch(in: t, range: r) != nil || englishRE.firstMatch(in: t, range: r) != nil { return true }
        if digits8.firstMatch(in: t, range: r) != nil { return true }
        if urlLike.firstMatch(in: t, range: r) != nil, t.filter({ $0 == "." }).count >= 2 { return true }
        return false
    }
}
