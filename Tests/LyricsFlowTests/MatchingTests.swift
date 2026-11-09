import Testing
@testable import LyricsFlow

struct TextMatchingTests {
    @Test func identicalStringsScoreOne() {
        #expect(TextMatching.similarity("beautifulmistakes", "beautifulmistakes") == 1.0)
    }

    @Test func similarityMatchesRatcliffObershelp() {
        // Same value as Python difflib.SequenceMatcher(None, "abcd", "bcde").ratio() == 0.75
        #expect(abs(TextMatching.similarity("abcd", "bcde") - 0.75) < 1e-9)
    }

    @Test func normalizeStripsBracketsAndPunctuation() {
        #expect(TextMatching.normalize("Beautiful Mistakes (feat. Megan Thee Stallion)") == "beautifulmistakes")
    }

    @Test func normalizeConvertsTraditionalToSimplified() {
        #expect(TextMatching.normalize("愛你") == "爱你")
    }
}

struct MatcherTests {
    private let meta = TrackMeta(title: "Beautiful Mistakes", artist: "Maroon 5", album: "", duration: 227)

    @Test func variantsStartWithTitleAndArtist() {
        let v = LyricsMatcher.variants(title: "Beautiful Mistakes (Live)", artist: "Maroon 5")
        #expect(v.first == "Beautiful Mistakes (Live) Maroon 5")
        #expect(v.contains("Beautiful Mistakes Maroon 5"))
        #expect(v.last == "Beautiful Mistakes (Live)")
        #expect(Set(v).count == v.count)
    }

    @Test func scorePrefersMatchingDuration() {
        let good = Candidate(title: "Beautiful Mistakes", artist: "Maroon 5", duration: 227, source: "x", ref: "1")
        let live = Candidate(title: "Beautiful Mistakes", artist: "Maroon 5", duration: 301, source: "x", ref: "2")
        #expect(LyricsMatcher.score(good, meta) > LyricsMatcher.score(live, meta))
    }

    @Test func durationCheckRejectsWrongVersion() {
        #expect(LyricsMatcher.durationOK(lastLineStart: 215, duration: 227))
        #expect(!LyricsMatcher.durationOK(lastLineStart: 40, duration: 227))
        #expect(!LyricsMatcher.durationOK(lastLineStart: 400, duration: 227))
        #expect(LyricsMatcher.durationOK(lastLineStart: 40, duration: 0))
    }
}
