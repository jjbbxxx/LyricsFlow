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
    private var artwork = ArtworkState(start: .distantPast, previousData: nil)
    private var lastTrack: Track?
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
            presentNewTrack(snap, position: position, playing: playing)
        } else {
            retryArtwork(snap)
            DispatchQueue.main.async { self.model.sync(position: position, playing: playing) }
        }
    }

    private func presentNewTrack(_ snap: MusicSnapshot, position: Double, playing: Bool) {
        let sameAlbum = currentSnapshot.map { $0.album == snap.album && $0.artist == snap.artist } ?? false
        currentKey = snap.trackKey
        currentSnapshot = snap
        artwork = ArtworkState(start: Date(), previousData: artwork.shownData, sameAlbumAsPrevious: sameAlbum)
        let found = findCover(snap)
        let track = makeTrack(snap, cover: found?.image, carryFrom: lastTrack)
        artwork = artwork.attempted(found: found, carried: found == nil && lastTrack != nil)
        lastTrack = track
        currentTrackID = track.id
        DispatchQueue.main.async { self.model.present(track: track, position: position, playing: playing) }
        startLyricsSearch(for: snap, trackID: track.id)
    }

    /// Keeps looking until a cover turns up; drops a carried-over cover after a few seconds.
    private func retryArtwork(_ snap: MusicSnapshot) {
        guard !artwork.resolved else { return }
        let now = Date()
        let elapsed = now.timeIntervalSince(artwork.start)
        var next: Track?
        if CoverRetryPolicy.shouldTry(elapsed: elapsed, sinceLastAttempt: now.timeIntervalSince(artwork.lastAttempt)) {
            let found = findCover(snap)
            artwork = artwork.attempted(found: found, carried: artwork.carried)
            if let found { next = makeTrack(snap, cover: found.image, id: currentTrackID) }
        }
        if next == nil, artwork.carried, CoverRetryPolicy.shouldDropCarriedCover(elapsed: elapsed) {
            artwork = artwork.attempted(found: nil, carried: false)
            next = makeTrack(snap, cover: nil, id: currentTrackID)
        }
        guard let track = next else { return }
        lastTrack = track
        DispatchQueue.main.async { self.model.update(track: track) }
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
        lastTrack = nil
        DispatchQueue.main.async { self.model.setIdle(status) }
    }

    private func makeTrack(_ snap: MusicSnapshot, cover: NSImage?, id: Int? = nil, carryFrom: Track? = nil) -> Track {
        TrackFactory.make(
            id: id ?? TrackFactory.nextID(),
            title: snap.title, artist: snap.artist, album: snap.album,
            duration: snap.durationSeconds, cover: cover, carryFrom: carryFrom
        )
    }

    /// AppleScript first; streamed tracks often expose no artwork there, so fall back to the
    /// image Music itself already downloaded (local cache, no network).
    private func findCover(_ snap: MusicSnapshot) -> FoundCover? {
        if let desc = try? run(&artScript, MusicScripts.artwork), desc.data.count > 16,
           !artwork.isStale(desc.data),
           let image = NSImage(data: desc.data) {
            return FoundCover(image: image, data: desc.data)
        }
        let cached = MusicArtworkCache.cover(title: snap.title, artist: snap.artist,
                                             album: snap.album, duration: snap.durationSeconds)
        return cached.map { FoundCover(image: $0, data: nil) }
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
