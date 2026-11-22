import Foundation

/// When to look for the current track's artwork again. Music writes streamed artwork to its cache
/// a moment after the track starts, so the first seconds retry on every poll, then back off.
/// Until a cover is found the previous one stays on screen (no flash of a placeholder);
/// only after `carryLimit` seconds is the placeholder shown.
enum CoverRetryPolicy {
    static let eagerWindow: TimeInterval = 10
    static let slowInterval: TimeInterval = 5
    static let giveUpAfter: TimeInterval = 120
    static let carryLimit: TimeInterval = 5

    static func shouldTry(elapsed: TimeInterval, sinceLastAttempt: TimeInterval) -> Bool {
        if elapsed < eagerWindow { return true }
        return elapsed < giveUpAfter && sinceLastAttempt >= slowInterval
    }

    static func shouldDropCarriedCover(elapsed: TimeInterval) -> Bool {
        elapsed >= carryLimit
    }

    /// Right after a track change AppleScript can still hand back the previous track's artwork.
    /// Identical bytes are only trusted when both tracks come from the same album.
    static func isStale(_ data: Data, previous: Data?, sameAlbum: Bool) -> Bool {
        !sameAlbum && data == previous
    }
}
