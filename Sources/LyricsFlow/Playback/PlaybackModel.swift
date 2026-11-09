import Foundation

enum LyricsPhase: Equatable { case searching, found, missing }

enum PlaybackStatus: Equatable {
    case demo, notRunning, stopped, permissionDenied, active
}

/// Single source of truth for what the renderer shows. All timing comes from one anchor
/// (position + wall-clock date) that the Apple Music bridge keeps calibrated; views only ever
/// ask `lyricTime(at:)`, so pause, seek and track change need no separate timer.
final class PlaybackModel: ObservableObject {
    private let settings: AppSettings

    @Published private(set) var status: PlaybackStatus = .notRunning
    @Published private(set) var track: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentIndex = -1
    @Published private(set) var lyricsPhase: LyricsPhase = .searching
    @Published private(set) var seekEpoch = 0
    @Published private(set) var animateScroll = true

    private var demoTracks: [Track] = []
    private var demoIndex = 0
    private var anchorPos = 0.0
    private var anchorDate = Date()
    private var timer: Timer?

    /// A reading further than this from the interpolated position is treated as a seek.
    private let seekThreshold = 0.45

    init(settings: AppSettings) {
        self.settings = settings
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.refreshIndex() }
    }

    // MARK: - Timeline

    func position(at date: Date) -> Double {
        isPlaying ? anchorPos + date.timeIntervalSince(anchorDate) : anchorPos
    }

    func lyricTime(at date: Date) -> Double { position(at: date) + settings.timeOffset }

    // MARK: - Live source (Apple Music bridge)

    func setIdle(_ status: PlaybackStatus) {
        guard self.status != status || track != nil else { return }
        log("IDLE \(status)")
        self.status = status
        track = nil
        isPlaying = false
        currentIndex = -1
    }

    func present(track: Track, position: Double, playing: Bool) {
        status = .active
        log("TRACK \(track.title) pos=\(String(format: "%.2f", position)) playing=\(playing)")
        self.track = track
        lyricsPhase = track.lyrics.lines.isEmpty ? .searching : .found
        anchorPos = position
        anchorDate = Date()
        isPlaying = playing
        hardSnap()
    }

    /// Late-arriving lyrics for the track that is still on screen; ignored if the track has changed.
    func updateLyrics(trackID: Int, lyrics: Lyrics?) {
        guard let current = track, current.id == trackID else { return }
        if let lyrics {
            track = current.withLyrics(lyrics)
            lyricsPhase = .found
            log("LYRICS \(lyrics.source) lines=\(lyrics.lines.count) precision=\(lyrics.precision)")
            hardSnap()
        } else {
            track = current.withLyrics(Lyrics(source: "none", lines: []))
            lyricsPhase = .missing
            log("LYRICS none")
        }
    }

    /// A new search was requested for the current track (source changed or re-match).
    func beginLyricsSearch() {
        guard let current = track else { return }
        track = current.withLyrics(Lyrics(source: "none", lines: []))
        lyricsPhase = .searching
        hardSnap()
    }

    /// Swap cover/metadata (e.g. late artwork) without touching the timeline or the lyrics already found.
    func update(track: Track) {
        guard let current = self.track, current.id == track.id else { return }
        self.track = current.lyrics.lines.isEmpty ? track : track.withLyrics(current.lyrics)
    }

    /// `position` is already compensated for query latency, i.e. the position at this instant.
    func sync(position: Double, playing: Bool) {
        let now = Date()
        let expected = self.position(at: now)
        if playing != isPlaying {
            log("STATE \(playing ? "play" : "pause") pos=\(String(format: "%.2f", position))")
            isPlaying = playing
            anchorPos = position
            anchorDate = now
            hardSnap()
        } else if playing, abs(position - expected) > seekThreshold {
            log("SEEK expected=\(String(format: "%.2f", expected)) actual=\(String(format: "%.2f", position))")
            anchorPos = position
            anchorDate = now
            hardSnap()
        } else if playing {
            anchorPos = expected + (position - expected) * 0.4
            anchorDate = now
        } else if abs(position - anchorPos) > 0.02 {
            log("SEEK(paused) from=\(String(format: "%.2f", anchorPos)) to=\(String(format: "%.2f", position))")
            anchorPos = position
            anchorDate = now
            hardSnap()
        }
    }

    // MARK: - Demo source (debug only; never touches Apple Music)

    func enterDemo(tracks: [Track]) {
        demoTracks = tracks
        status = .demo
        selectDemo(0)
    }

    func selectDemo(_ index: Int, at seconds: Double = 0) {
        guard status == .demo, !demoTracks.isEmpty else { return }
        demoIndex = (index % demoTracks.count + demoTracks.count) % demoTracks.count
        track = demoTracks[demoIndex]
        anchorPos = seconds
        anchorDate = Date()
        isPlaying = true
        hardSnap()
    }

    func nextDemo() { selectDemo(demoIndex + 1) }
    func previousDemo() { selectDemo(demoIndex - 1) }

    func toggleDemoPlay() {
        guard status == .demo else { return }
        let now = Date()
        anchorPos = position(at: now)
        anchorDate = now
        isPlaying.toggle()
    }

    func seekDemo(by delta: Double) {
        guard status == .demo, let track else { return }
        anchorPos = min(max(position(at: Date()) + delta, 0), track.duration)
        anchorDate = Date()
        hardSnap()
    }

    // MARK: - Index

    /// Debug trace (`--log`): appends to /tmp/lyricsflow.log.
    static let logEnabled = CommandLine.arguments.contains("--log")
    private func log(_ message: String) {
        guard Self.logEnabled else { return }
        let line = String(format: "%.3f %@\n", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 10000), message)
        if let h = FileHandle(forWritingAtPath: "/tmp/lyricsflow.log") ?? { FileManager.default.createFile(atPath: "/tmp/lyricsflow.log", contents: nil); return FileHandle(forWritingAtPath: "/tmp/lyricsflow.log") }() {
            h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
        }
    }

    private func hardSnap() {
        seekEpoch += 1
        currentIndex = -1
        animateScroll = false
        refreshIndex(forceInstant: true)
    }

    private func refreshIndex(forceInstant: Bool = false) {
        guard let track else { return }
        let new = track.lyrics.index(at: lyricTime(at: Date()))
        guard new != currentIndex else { return }
        animateScroll = !forceInstant && abs(new - currentIndex) <= 2
        currentIndex = new
    }
}
