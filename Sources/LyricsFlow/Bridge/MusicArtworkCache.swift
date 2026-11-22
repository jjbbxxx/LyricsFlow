import AppKit
import SQLite3

/// Reads artwork that Music.app itself has already downloaded, straight from its URL cache
/// (`~/Library/Caches/com.apple.Music/Cache.db`). Streamed Apple Music tracks often expose no
/// artwork over AppleScript even though Music displays one; Music fetched that image and its
/// catalog record through this cache, so both can be read locally. Never touches the network.
/// Opened read-only; a missing or changed cache layout simply yields nil.
enum MusicArtworkCache {
    private static let base = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/com.apple.Music")
    private static let catalogPrefix = "https://amp-api.music.apple.com/v1/catalog/"
    private static let recentCatalogRows = 80

    static func cover(title: String, artist: String, album: String, duration: Double) -> NSImage? {
        guard let db = open() else { return nil }
        defer { sqlite3_close(db) }
        let songs = recentCatalogSongs(db)
        guard let song = CatalogMatcher.best(songs, title: title, artist: artist, album: album, duration: duration),
              let prefix = song.artworkPrefix else { return nil }
        return largestImage(db, prefix: prefix)
    }

    // MARK: - SQLite

    private static func open() -> OpaquePointer? {
        let path = base.appendingPathComponent("Cache.db").path
        guard FileManager.default.isReadableFile(atPath: path) else { return nil }
        var db: OpaquePointer?
        let uri = "file:\(path)?mode=ro"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        sqlite3_busy_timeout(db, 200)
        return db
    }

    private struct Row {
        let key: String
        let onDisk: Bool
        let blob: Data
    }

    /// Rows whose request key starts with `prefix`, newest first.
    private static func rows(_ db: OpaquePointer, prefix: String, limit: Int) -> [Row] {
        let sql = """
        SELECT r.request_key, d.isDataOnFS, d.receiver_data
        FROM cfurl_cache_response r JOIN cfurl_cache_receiver_data d ON d.entry_ID = r.entry_ID
        WHERE substr(r.request_key, 1, ?1) = ?2
        ORDER BY r.time_stamp DESC, r.entry_ID DESC LIMIT ?3
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_int(stmt, 1, Int32(prefix.utf8.count))
        sqlite3_bind_text(stmt, 2, prefix, -1, transient)
        sqlite3_bind_int(stmt, 3, Int32(limit))
        var out: [Row] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let k = sqlite3_column_text(stmt, 0) else { continue }
            let n = Int(sqlite3_column_bytes(stmt, 2))
            let blob = sqlite3_column_blob(stmt, 2).map { Data(bytes: $0, count: n) } ?? Data()
            out.append(Row(key: String(cString: k), onDisk: sqlite3_column_int(stmt, 1) != 0, blob: blob))
        }
        return out
    }

    /// Small bodies live inline; large ones in `fsCachedData/<name>`.
    private static func body(_ row: Row) -> Data? {
        guard row.onDisk else { return row.blob.isEmpty ? nil : row.blob }
        guard let name = String(data: row.blob, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty, !name.contains("/") else { return nil }
        return try? Data(contentsOf: base.appendingPathComponent("fsCachedData").appendingPathComponent(name))
    }

    private static func recentCatalogSongs(_ db: OpaquePointer) -> [CatalogSong] {
        rows(db, prefix: catalogPrefix, limit: recentCatalogRows).flatMap { row in
            body(row).map(CatalogSong.parse) ?? []
        }
    }

    private static func largestImage(_ db: OpaquePointer, prefix: String) -> NSImage? {
        let candidates = rows(db, prefix: prefix, limit: 12)
            .sorted { ArtworkSize.width(of: $0.key, after: prefix) > ArtworkSize.width(of: $1.key, after: prefix) }
        for row in candidates {
            if let data = body(row), let image = NSImage(data: data), image.isValid { return image }
        }
        return nil
    }
}

/// Parses the rendered size from an artwork URL suffix such as `800x800bb.jpg`.
enum ArtworkSize {
    static func width(of key: String, after prefix: String) -> Int {
        guard key.hasPrefix(prefix) else { return 0 }
        let digits = key.dropFirst(prefix.count).prefix { $0.isNumber }
        return Int(digits) ?? 0
    }
}
