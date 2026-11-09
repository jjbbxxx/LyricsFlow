import Testing
@testable import LyricsFlow

struct PinnedCacheTests {
    private let meta = TrackMeta(title: "Song", artist: "Artist", album: "", duration: 200)

    private func lyrics(_ source: String, _ text: String) -> Lyrics {
        Lyrics(source: source, lines: [LyricLine(id: 0, start: 1, end: 3, text: text)])
    }

    @Test func pinnedRoundTrips() {
        let cache = LyricsCache.temporary()
        #expect(cache.loadPinned(meta) == nil)
        cache.storePinned(lyrics("qq", "hello"), meta)
        #expect(cache.loadPinned(meta)?.lines.first?.text == "hello")
        #expect(cache.loadPinned(meta)?.source == "qq")
    }

    @Test func removingUndoesThePin() {
        let cache = LyricsCache.temporary()
        cache.storePinned(lyrics("qq", "hello"), meta)
        cache.removePinned(meta)
        #expect(cache.loadPinned(meta) == nil)
    }

    @Test func pinnedAndAutomaticEntriesDoNotCollide() {
        let cache = LyricsCache.temporary()
        cache.store(lyrics("netease", "auto"), meta, .auto)
        cache.storePinned(lyrics("qq", "chosen"), meta)
        #expect(cache.load(meta, .auto)?.lines.first?.text == "auto")
        #expect(cache.loadPinned(meta)?.lines.first?.text == "chosen")
    }

    @Test func differentVersionsOfASongAreKeptApart() {
        let cache = LyricsCache.temporary()
        cache.storePinned(lyrics("qq", "studio"), meta)
        let live = TrackMeta(title: "Song", artist: "Artist", album: "", duration: 310)
        #expect(cache.loadPinned(live) == nil)
    }

    @Test func wordLevelDataSurvivesTheDiskRoundTrip() {
        let cache = LyricsCache.temporary()
        let words = [LyricWord(text: "hel", start: 1, end: 1.4), LyricWord(text: "lo", start: 1.4, end: 2)]
        cache.storePinned(Lyrics(source: "netease", lines: [LyricLine(id: 0, words: words)]), meta)
        let back = cache.loadPinned(meta)
        #expect(back?.precision == .word)
        #expect(back?.lines.first?.words?.count == 2)
        #expect(back?.lines.first?.wordRanges == [0..<3, 3..<5])
    }
}
