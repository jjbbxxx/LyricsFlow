import AppKit

/// Observes Music.app (state notification for instant reaction + 1 s position calibration).
/// Never launches Music, never sends playback commands.
final class MusicBridge {
    private enum ScriptError: Error { case denied, failed }

    private static let musicBundleID = "com.apple.Music"
    private static let errAuthorization = -1743

    private let model: PlaybackModel
    private let settings: AppSettings
    private let queue = DispatchQueue(label: "lyricsflow.music-bridge", qos: .userInitiated)
    private var readScript: NSAppleScript?
    private var artScript: NSAppleScript?
    private var timer: DispatchSourceTimer?
    private var observer: NSObjectProtocol?

    private var currentKey: String?
    private var currentTrackID = 0
    private var artworkRetries = 0
    private var currentSnapshot: MusicSnapshot?
    private var pollQueued = false
    private var lyricsTask: Task<Void, Never>?

    init(model: PlaybackModel, settings: AppSettings) {
        self.model = model
        self.settings = settings
    }

    /// Re-run the lyric search for the current track; `refresh` ignores the cache.
    func rematch(refresh: Bool) {
        queue.async { [weak self] in
            guard let self, let snap = self.currentSnapshot, self.currentKey != nil else { return }
            DispatchQueue.main.async { self.model.beginLyricsSearch() }
            self.startLyricsSearch(for: snap, trackID: self.currentTrackID, refresh: refresh)
        }
    }

    func start() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"), object: nil, queue: nil
        ) { [weak self] _ in self?.requestPoll() }

        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(50))
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    /// Coalesces bursts (Music posts several notifications per track change).
    private func requestPoll() {
        queue.async { [weak self] in
            guard let self, !self.pollQueued else { return }
            self.pollQueued = true
            self.queue.asyncAfter(deadline: .now() + 0.08) {
                self.pollQueued = false
                self.poll()
            }
        }
    }

    // MARK: - Poll (runs on `queue`)

    private func poll() {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: Self.musicBundleID).first != nil else {
            reset(.notRunning)
            return
        }
        let started = Date()
        let raw: String
        do { raw = try run(&readScript, MusicScripts.nowPlaying).stringValue ?? "" }
        catch ScriptError.denied { reset(.permissionDenied); return }
        catch { return }
        let latency = Date().timeIntervalSince(started)

        if raw == "STOPPED" { reset(.stopped); return }
        guard let snap = MusicSnapshot.parse(raw) else { return }

        // The position was sampled roughly mid-query.
        let playing = snap.state == .playing
        let position = snap.positionSeconds + (playing ? latency / 2 : 0)

        if snap.trackKey != currentKey {
            currentKey = snap.trackKey
            currentSnapshot = snap
            artworkRetries = 3
            let track = makeTrack(snap, cover: fetchCover())
            let id = track.id
            currentTrackID = id
            DispatchQueue.main.async { self.model.present(track: track, position: position, playing: playing) }
            startLyricsSearch(for: snap, trackID: id)
        } else {
            if artworkRetries > 0, let cover = fetchCover() {
                artworkRetries = 0
                let track = makeTrack(snap, cover: cover, id: currentTrackID)
                DispatchQueue.main.async { self.model.update(track: track) }
            } else if artworkRetries > 0 {
                artworkRetries -= 1
            }
            DispatchQueue.main.async { self.model.sync(position: position, playing: playing) }
        }
    }

    private func startLyricsSearch(for snap: MusicSnapshot, trackID: Int, refresh: Bool = false) {
        lyricsTask?.cancel()
        guard !TrackFactory.attachDemoLyrics else { return }
        let meta = TrackMeta(title: snap.title, artist: snap.artist, album: snap.album, duration: snap.durationSeconds)
        let settings = self.settings, model = self.model
        lyricsTask = Task {
            // Debounce: skipping through tracks should not fire a request per track.
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            let source = await MainActor.run { settings.lyricSource }
            let lyrics = await LyricsResolver.shared.resolve(meta, source: source, refresh: refresh)
            if Task.isCancelled { return }
            await MainActor.run { model.updateLyrics(trackID: trackID, lyrics: lyrics) }
        }
    }

    private func reset(_ status: PlaybackStatus) {
        lyricsTask?.cancel()
        currentKey = nil
        DispatchQueue.main.async { self.model.setIdle(status) }
    }

    private func makeTrack(_ snap: MusicSnapshot, cover: NSImage?, id: Int? = nil) -> Track {
        TrackFactory.make(
            id: id ?? TrackFactory.nextID(),
            title: snap.title, artist: snap.artist, album: snap.album,
            duration: snap.durationSeconds, cover: cover
        )
    }

    private func fetchCover() -> NSImage? {
        guard let desc = try? run(&artScript, MusicScripts.artwork), desc.data.count > 16 else { return nil }
        return NSImage(data: desc.data)
    }

    private func run(_ cache: inout NSAppleScript?, _ source: String) throws -> NSAppleEventDescriptor {
        if cache == nil { cache = NSAppleScript(source: source) }
        guard let script = cache else { throw ScriptError.failed }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            throw code == Self.errAuthorization ? ScriptError.denied : ScriptError.failed
        }
        return result
    }
}
