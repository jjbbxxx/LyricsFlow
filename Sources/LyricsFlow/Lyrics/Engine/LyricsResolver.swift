import Foundation

/// Multi-source lookup, same order and rules as Kindle's lyrics.py `get_lyrics`:
/// NetEase, QQ, Kugou by score, then LRCLIB. Never returns lyrics from a different version.
///
/// A source in rate-limit cooldown is skipped. A result obtained while a better source was skipped
/// is "degraded": it is shown, but kept only briefly in memory and never written to the disk cache,
/// so the next play retries the better source instead of freezing a line-level result.
actor LyricsResolver {
    static let shared = LyricsResolver()

    private struct Outcome {
        var lyrics: Lyrics?
        var degraded = false
    }

    private let cache = LyricsCache()
    private var misses: [String: Date] = [:]
    private var provisional: [String: (lyrics: Lyrics, at: Date)] = [:]
    private let missTTL: TimeInterval = 120
    private let degradedTTL: TimeInterval = 90
    private let health = SourceHealth.shared

    private let sources: [String: LyricSource] = [
        "netease": NeteaseSource(), "qq": QQSource(), "kugou": KugouSource(),
    ]

    func resolve(_ meta: TrackMeta, source: SourcePreference = .auto, refresh: Bool = false) async -> Lyrics? {
        // A lyric the user picked by hand always wins.
        if let pinned = cache.loadPinned(meta) { return pinned }
        let key = cache.key(meta, source)
        if refresh {
            cache.remove(meta, source)
            misses[key] = nil
            provisional[key] = nil
        } else {
            if let hit = cache.load(meta, source) { return hit }
            if let p = provisional[key], Date().timeIntervalSince(p.at) < degradedTTL { return p.lyrics }
            if let t = misses[key], Date().timeIntervalSince(t) < missTTL { return nil }
        }

        let outcome = await search(meta, source)
        if Task.isCancelled { return nil }
        switch (outcome.lyrics, outcome.degraded) {
        case let (lyrics?, false): cache.store(lyrics, meta, source)
        case let (lyrics?, true): provisional[key] = (lyrics, Date())
        case (nil, false): misses[key] = Date()
        case (nil, true): misses[key] = Date().addingTimeInterval(30 - missTTL)
        }
        return outcome.lyrics
    }

    private func search(_ meta: TrackMeta, _ preference: SourcePreference) async -> Outcome {
        switch preference {
        case .auto:
            var degraded = false
            for id in ["netease", "qq", "kugou"] {
                if await health.isCoolingDown(id) { degraded = true; continue }
                if let l = await best(from: sources[id]!, meta) { return Outcome(lyrics: l, degraded: degraded) }
                if Task.isCancelled { return Outcome() }
                if await health.isCoolingDown(id) { degraded = true }
            }
            return Outcome(lyrics: await lrclib(meta), degraded: degraded)
        case .lrclib:
            return Outcome(lyrics: await lrclib(meta))
        default:
            guard let s = sources[preference.rawValue] else { return Outcome() }
            if await health.isCoolingDown(s.id) { return Outcome(lyrics: nil, degraded: true) }
            let l = await best(from: s, meta)
            let throttled = await health.isCoolingDown(s.id)
            return Outcome(lyrics: l, degraded: l == nil && throttled)
        }
    }

    /// Variants are queried one after another; a confident match stops the loop early.
    private func best(from source: LyricSource, _ meta: TrackMeta) async -> Lyrics? {
        var candidates: [Candidate] = []
        for query in LyricsMatcher.variants(title: meta.title, artist: meta.artist) {
            candidates += await source.search(query)
            if Task.isCancelled { return nil }
            if await health.isCoolingDown(source.id) { break }
            if let (_, score) = LyricsMatcher.best(candidates, for: meta), score >= LyricsMatcher.confidentScore { break }
        }
        guard let (cand, score) = LyricsMatcher.best(candidates, for: meta),
              score >= LyricsMatcher.minimumScore else { return nil }
        guard let lyrics = LyricsAssembler.build(await source.fetch(cand), source: source.id),
              let last = lyrics.lines.last,
              LyricsMatcher.durationOK(lastLineStart: last.start, duration: meta.duration) else { return nil }
        return lyrics
    }

    private func lrclib(_ meta: TrackMeta) async -> Lyrics? {
        guard let raw = await LRCLibSource.lyrics(for: meta),
              let lyrics = LyricsAssembler.build(raw, source: "lrclib"),
              let last = lyrics.lines.last,
              LyricsMatcher.durationOK(lastLineStart: last.start, duration: meta.duration) else { return nil }
        return lyrics
    }

    // MARK: - Manual search (lyric search window)

    struct SearchHit: Identifiable {
        let candidate: Candidate
        let score: Double
        var id: String { "\(candidate.source):\(candidate.ref)" }
    }

    struct SearchResult {
        var hits: [SearchHit] = []
        /// Sources skipped because they are rate limited right now.
        var throttled: [String] = []
    }

    private var allSources: [String: LyricSource] {
        var all = sources
        all["lrclib"] = LRCLibSource()
        return all
    }

    /// Free-text search over the chosen sources in parallel; scores are relative to the playing track.
    func search(query: String, for meta: TrackMeta, sourceIDs: [String]) async -> SearchResult {
        var result = SearchResult()
        var active: [LyricSource] = []
        for id in sourceIDs {
            guard let s = allSources[id] else { continue }
            if await health.isCoolingDown(id) { result.throttled.append(id) } else { active.append(s) }
        }
        let found = await withTaskGroup(of: [Candidate].self) { group -> [[Candidate]] in
            for s in active { group.addTask { await s.search(query) } }
            var all: [[Candidate]] = []
            for await c in group { all.append(c) }
            return all
        }
        for id in sourceIDs where await health.isCoolingDown(id) && !result.throttled.contains(id) {
            result.throttled.append(id)
        }
        result.hits = found.flatMap { $0 }
            .map { SearchHit(candidate: $0, score: LyricsMatcher.score($0, meta)) }
            .sorted { $0.score > $1.score }
        return result
    }

    /// Fetches and parses one candidate for preview. No version check: the user decides.
    func preview(_ hit: SearchHit) async -> Lyrics? {
        guard let s = allSources[hit.candidate.source] else { return nil }
        return LyricsAssembler.build(await s.fetch(hit.candidate), source: s.id)
    }

    func pin(_ lyrics: Lyrics, for meta: TrackMeta) {
        cache.storePinned(lyrics, meta)
    }

    func unpin(_ meta: TrackMeta) {
        cache.removePinned(meta)
        for pref in SourcePreference.allCases { cache.remove(meta, pref) }
        provisional.removeAll()
        misses.removeAll()
    }

    func isPinned(_ meta: TrackMeta) -> Bool { cache.loadPinned(meta) != nil }
}
