import Testing
@testable import LyricsFlow

struct LyricsFingerprintTests {
    private func lyrics(_ source: String, _ texts: [String]) -> Lyrics {
        Lyrics(source: source, lines: texts.enumerated().map { i, t in
            LyricLine(id: i, start: Double(i) * 3, end: Double(i) * 3 + 3, text: t)
        })
    }

    @Test func sameContentHasSameFingerprint() {
        #expect(lyrics("qq", ["a", "b"]).fingerprint == lyrics("qq", ["a", "b"]).fingerprint)
    }

    @Test func differentTextChangesTheFingerprint() {
        #expect(lyrics("qq", ["a", "b"]).fingerprint != lyrics("qq", ["a", "c"]).fingerprint)
        #expect(lyrics("qq", ["a", "b"]).fingerprint != lyrics("qq", ["x", "b"]).fingerprint)
    }

    @Test func differentSourceOrLengthChangesTheFingerprint() {
        #expect(lyrics("qq", ["a", "b"]).fingerprint != lyrics("kugou", ["a", "b"]).fingerprint)
        #expect(lyrics("qq", ["a", "b"]).fingerprint != lyrics("qq", ["a", "b", "c"]).fingerprint)
    }

    @Test func emptyLyricsHaveAStableFingerprint() {
        #expect(Lyrics(source: "none", lines: []).fingerprint == Lyrics(source: "none", lines: []).fingerprint)
    }
}
