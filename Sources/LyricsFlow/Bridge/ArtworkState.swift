import AppKit

struct FoundCover {
    let image: NSImage
    /// Raw AppleScript bytes; nil when the image came from Music's cache.
    let data: Data?
}

/// Artwork lookup progress for the current track (owned by the bridge queue; replaced, never mutated).
struct ArtworkState {
    let start: Date
    let lastAttempt: Date
    let resolved: Bool
    /// The previous track's cover is still on screen.
    let carried: Bool
    /// AppleScript bytes of the cover now shown, for stale detection on the next change.
    let shownData: Data?
    /// AppleScript bytes shown for the previous track.
    let previousData: Data?
    let sameAlbumAsPrevious: Bool

    init(start: Date, previousData: Data?, sameAlbumAsPrevious: Bool = false) {
        self.init(start: start, lastAttempt: start, resolved: false, carried: false, shownData: nil,
                  previousData: previousData, sameAlbumAsPrevious: sameAlbumAsPrevious)
    }

    private init(start: Date, lastAttempt: Date, resolved: Bool, carried: Bool, shownData: Data?,
                 previousData: Data?, sameAlbumAsPrevious: Bool) {
        self.start = start
        self.lastAttempt = lastAttempt
        self.resolved = resolved
        self.carried = carried
        self.shownData = shownData
        self.previousData = previousData
        self.sameAlbumAsPrevious = sameAlbumAsPrevious
    }

    func attempted(found: FoundCover?, carried: Bool, at now: Date = Date()) -> ArtworkState {
        ArtworkState(start: start, lastAttempt: now, resolved: found != nil,
                     carried: found == nil && carried, shownData: found?.data,
                     previousData: previousData, sameAlbumAsPrevious: sameAlbumAsPrevious)
    }

    func isStale(_ data: Data) -> Bool {
        CoverRetryPolicy.isStale(data, previous: previousData, sameAlbum: sameAlbumAsPrevious)
    }
}
