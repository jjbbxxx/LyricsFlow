import Foundation
import CryptoKit

/// Positive results only, on disk. Misses are remembered in memory by the resolver for a short time.
struct LyricsCache {
    let directory: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LyricsFlow/lyrics", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    func key(_ meta: TrackMeta, _ source: SourcePreference) -> String { key(meta, tag: source.rawValue) }

    func key(_ meta: TrackMeta, tag: String) -> String {
        let raw = "\(meta.title)\u{1F}\(meta.artist)\u{1F}\(Int(meta.duration.rounded()))\u{1F}\(tag)"
        return SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // A pinned choice is picked by the user and always wins over automatic matching.
    func loadPinned(_ meta: TrackMeta) -> Lyrics? { load(url(meta, tag: "pinned")) }
    func storePinned(_ lyrics: Lyrics, _ meta: TrackMeta) { store(lyrics, to: url(meta, tag: "pinned")) }
    func removePinned(_ meta: TrackMeta) { try? FileManager.default.removeItem(at: url(meta, tag: "pinned")) }

    func load(_ meta: TrackMeta, _ source: SourcePreference) -> Lyrics? { load(file(meta, source)) }

    func store(_ lyrics: Lyrics, _ meta: TrackMeta, _ source: SourcePreference) { store(lyrics, to: file(meta, source)) }

    private func load(_ url: URL) -> Lyrics? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Lyrics.self, from: data)
    }

    private func store(_ lyrics: Lyrics, to url: URL) {
        guard let data = try? JSONEncoder().encode(lyrics) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func url(_ meta: TrackMeta, tag: String) -> URL {
        directory.appendingPathComponent(key(meta, tag: tag) + ".json")
    }

    func remove(_ meta: TrackMeta, _ source: SourcePreference) {
        try? FileManager.default.removeItem(at: file(meta, source))
    }

    private func file(_ meta: TrackMeta, _ source: SourcePreference) -> URL {
        directory.appendingPathComponent(key(meta, source) + ".json")
    }
}

extension LyricsCache {
    /// Cache in a fresh temporary directory (tests).
    static func temporary() -> LyricsCache {
        LyricsCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("LyricsFlowTests-\(UUID().uuidString)", isDirectory: true))
    }
}
