import Testing
@testable import LyricsFlow

struct CooldownTrackerTests {
    private let t0 = 1_000_000.0

    @Test func startsHealthy() {
        let c = CooldownTracker()
        #expect(!c.isCoolingDown("netease", now: t0))
    }

    @Test func firstTripCoolsDownForBaseDuration() {
        var c = CooldownTracker()
        c.trip("netease", now: t0)
        #expect(c.isCoolingDown("netease", now: t0 + 59))
        #expect(!c.isCoolingDown("netease", now: t0 + 61))
    }

    @Test func repeatedTripsBackOffAndAreCapped() {
        var c = CooldownTracker()
        c.trip("netease", now: t0)
        c.trip("netease", now: t0)
        #expect(c.isCoolingDown("netease", now: t0 + 119))
        #expect(!c.isCoolingDown("netease", now: t0 + 121))
        for _ in 0..<10 { c.trip("netease", now: t0) }
        #expect(c.isCoolingDown("netease", now: t0 + 899))
        #expect(!c.isCoolingDown("netease", now: t0 + 901))
    }

    @Test func successResetsTheBackoff() {
        var c = CooldownTracker()
        c.trip("netease", now: t0)
        c.trip("netease", now: t0)
        c.success("netease")
        c.trip("netease", now: t0)
        #expect(!c.isCoolingDown("netease", now: t0 + 61))
    }

    @Test func sourcesAreIndependent() {
        var c = CooldownTracker()
        c.trip("netease", now: t0)
        #expect(!c.isCoolingDown("qq", now: t0))
    }
}
