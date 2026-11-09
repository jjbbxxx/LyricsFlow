import Foundation

/// Fake playback source for Milestone 1. Replaced by the Apple Music bridge in M2.
final class MockPlayer: ObservableObject {
    let tracks: [Track]
    private let settings: AppSettings

    @Published private(set) var trackIndex = 0
    @Published private(set) var isPlaying = true
    @Published private(set) var currentIndex = -1
    @Published private(set) var seekEpoch = 0
    @Published private(set) var animateScroll = true

    private var anchorPos = 0.0
    private var anchorDate = Date()
    private var timer: Timer?

    var track: Track { tracks[trackIndex] }

    init(tracks: [Track], settings: AppSettings) {
        self.tracks = tracks
        self.settings = settings
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
    }

    func position(at date: Date) -> Double {
        isPlaying ? anchorPos + date.timeIntervalSince(anchorDate) : anchorPos
    }

    func lyricTime(at date: Date) -> Double { position(at: date) + settings.timeOffset }

    func togglePlay() {
        let now = Date()
        anchorPos = position(at: now)
        anchorDate = now
        isPlaying.toggle()
    }

    func seek(to seconds: Double) {
        anchorPos = min(max(seconds, 0), track.duration)
        anchorDate = Date()
        seekEpoch += 1
        refreshIndex()
    }

    func seek(by delta: Double) { seek(to: position(at: Date()) + delta) }

    func select(_ index: Int, at seconds: Double = 0) {
        trackIndex = (index % tracks.count + tracks.count) % tracks.count
        currentIndex = -1
        animateScroll = false
        seek(to: seconds)
    }

    func next() { select(trackIndex + 1) }
    func previous() { select(trackIndex - 1) }

    private func tick() {
        if position(at: Date()) >= track.duration { seek(to: 0); return }
        refreshIndex()
    }

    private func refreshIndex() {
        let new = track.lyrics.index(at: lyricTime(at: Date()))
        guard new != currentIndex else { return }
        animateScroll = abs(new - currentIndex) <= 2
        currentIndex = new
    }
}
