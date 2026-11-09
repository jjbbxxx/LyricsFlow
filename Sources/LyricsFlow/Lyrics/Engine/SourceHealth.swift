import Foundation

/// Per-source rate-limit cooldown with doubling back-off (60 s, 120 s, ... capped at 15 min).
/// Pure value type so the timing is testable; `SourceHealth` is the shared, thread-safe wrapper.
struct CooldownTracker {
    static let base = 60.0
    static let cap = 900.0

    private var until: [String: Double] = [:]
    private var strikes: [String: Int] = [:]

    func isCoolingDown(_ id: String, now: Double) -> Bool {
        (until[id] ?? 0) > now
    }

    mutating func trip(_ id: String, now: Double) {
        let n = (strikes[id] ?? 0) + 1
        strikes[id] = n
        until[id] = now + min(Self.base * pow(2, Double(n - 1)), Self.cap)
    }

    mutating func success(_ id: String) {
        strikes[id] = 0
    }
}

actor SourceHealth {
    static let shared = SourceHealth()
    private var tracker = CooldownTracker()

    func isCoolingDown(_ id: String) -> Bool {
        tracker.isCoolingDown(id, now: Date().timeIntervalSince1970)
    }

    func tripRateLimit(_ id: String) {
        tracker.trip(id, now: Date().timeIntervalSince1970)
    }

    func recordSuccess(_ id: String) {
        tracker.success(id)
    }
}
