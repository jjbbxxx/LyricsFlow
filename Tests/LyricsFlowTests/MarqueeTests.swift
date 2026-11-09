import Testing
@testable import LyricsFlow

struct MarqueeMathTests {
    private let m = MarqueeMath(period: 400, pause: 1.5, duration: 5)

    @Test func staysAtStartDuringInitialPause() {
        #expect(m.offset(elapsed: 0) == 0)
        #expect(m.offset(elapsed: 1.49) == 0)
    }

    @Test func reachesOneFullPeriodAtTheEndOfTheScroll() {
        #expect(abs(m.offset(elapsed: 1.5 + 5 - 0.0001) - (-400)) < 0.5)
    }

    @Test func loopsBackToStartAfterOneCycle() {
        #expect(m.offset(elapsed: 6.5) == 0)
        #expect(m.offset(elapsed: 6.5 + 0.7) == 0)
        #expect(m.offset(elapsed: 6.5 + 1.5 + 2.5) == m.offset(elapsed: 1.5 + 2.5))
    }

    @Test func easesInAndOut() {
        // Slow at both ends: the first and last 5% of the scroll cover far less than 5% of the distance.
        let early = abs(m.offset(elapsed: 1.5 + 0.25))
        let lateRemaining = 400 - abs(m.offset(elapsed: 1.5 + 5 - 0.25))
        #expect(early < 400 * 0.05 * 0.2)
        #expect(lateRemaining < 400 * 0.05 * 0.2)
        // And the middle is exactly half way.
        #expect(abs(m.offset(elapsed: 1.5 + 2.5) - (-200)) < 1e-9)
    }

    @Test func movesOnlyLeft() {
        var last = 0.0
        for i in 0..<60 {
            let o = m.offset(elapsed: 1.5 + Double(i) * 5 / 60)
            #expect(o <= last + 1e-9)
            last = o
        }
    }

    @Test func durationScalesWithDistanceWithAFloor() {
        #expect(MarqueeMath.duration(period: 100) == 2.5)
        #expect(MarqueeMath.duration(period: 800) == 800 / 40)
    }
}

struct SubtitleTests {
    @Test func joinsArtistAndAlbumWithDash() {
        #expect(TrackText.subtitle(artist: "Olivia Rodrigo", album: "GUTS") == "Olivia Rodrigo — GUTS")
    }

    @Test func omitsMissingParts() {
        #expect(TrackText.subtitle(artist: "A", album: "") == "A")
        #expect(TrackText.subtitle(artist: "", album: "B") == "B")
        #expect(TrackText.subtitle(artist: " ", album: " ") == "")
    }
}
