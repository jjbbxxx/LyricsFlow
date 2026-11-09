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

    func key(_ meta: TrackMeta, _ source: SourcePreference) -> String {
        let raw = "\(meta.title)\u{1F}\(meta.artist)\u{1F}\(Int(meta.duration.rounded()))\u{1F}\(source.rawValue)"
        return SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func load(_ meta: TrackMeta, _ source: SourcePreference) -> Lyrics? {
        guard let data = try? Data(contentsOf: file(meta, source)) else { return nil }
        return try? JSONDecoder().decode(Lyrics.self, from: data)
    }

    func store(_ lyrics: Lyrics, _ meta: TrackMeta, _ source: SourcePreference) {
        guard let data = try? JSONEncoder().encode(lyrics) else { return }
        try? data.write(to: file(meta, source), options: .atomic)
    }

    func remove(_ meta: TrackMeta, _ source: SourcePreference) {
        try? FileManager.default.removeItem(at: file(meta, source))
    }

    private func file(_ meta: TrackMeta, _ source: SourcePreference) -> URL {
        directory.appendingPathComponent(key(meta, source) + ".json")
    }
}
