import Foundation

/// Multi-source lookup, same order and rules as Kindle's lyrics.py `get_lyrics`:
/// NetEase, QQ, Kugou by score, then LRCLIB. Never returns lyrics from a different version.
actor LyricsResolver {
    static let shared = LyricsResolver()

    private let cache = LyricsCache()
    private var misses: [String: Date] = [:]
    private let missTTL: TimeInterval = 120

    private let sources: [String: LyricSource] = [
        "netease": NeteaseSource(), "qq": QQSource(), "kugou": KugouSource(),
    ]

    func resolve(_ meta: TrackMeta, source: SourcePreference = .auto, refresh: Bool = false) async -> Lyrics? {
        let key = cache.key(meta, source)
        if refresh {
            cache.remove(meta, source)
            misses[key] = nil
        } else {
            if let hit = cache.load(meta, source) { return hit }
            if let t = misses[key], Date().timeIntervalSince(t) < missTTL { return nil }
        }

        let found = await search(meta, source)
        if Task.isCancelled { return nil }
        if let found { cache.store(found, meta, source) } else { misses[key] = Date() }
        return found
    }

    private func search(_ meta: TrackMeta, _ preference: SourcePreference) async -> Lyrics? {
        switch preference {
        case .auto:
            for id in ["netease", "qq", "kugou"] {
                if let l = await best(from: sources[id]!, meta) { return l }
                if Task.isCancelled { return nil }
            }
            return await lrclib(meta)
        case .lrclib:
            return await lrclib(meta)
        default:
            guard let s = sources[preference.rawValue] else { return nil }
            return await best(from: s, meta)
        }
    }

    private func best(from source: LyricSource, _ meta: TrackMeta) async -> Lyrics? {
        let queries = LyricsMatcher.variants(title: meta.title, artist: meta.artist)
        let batches = await withTaskGroup(of: (Int, [Candidate]).self) { group -> [[Candidate]] in
            for (i, q) in queries.enumerated() { group.addTask { (i, await source.search(q)) } }
            var out = Array(repeating: [Candidate](), count: queries.count)
            for await (i, c) in group { out[i] = c }
            return out
        }
        guard let (cand, score) = LyricsMatcher.best(batches.flatMap { $0 }, for: meta),
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
}
