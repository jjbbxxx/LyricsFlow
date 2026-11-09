import Foundation

/// Kugou serves over plain HTTP (the HTTPS host name does not match its certificate);
/// Info.plist carries an ATS exception for kugou.com.
struct KugouSource: LyricSource {
    let id = "kugou"

    func search(_ query: String) async -> [Candidate] {
        let js = await HTTPClient.json("http://mobilecdn.kugou.com/api/v3/search/song",
                                       [("format", "json"), ("keyword", query), ("page", "1"), ("pagesize", "8"), ("showtype", "1")])
        let info = ((js?["data"] as? [String: Any])?["info"] as? [[String: Any]]) ?? []
        return info.compactMap { s in
            let hash = asString(s["hash"])
            guard !hash.isEmpty else { return nil }
            return Candidate(title: asString(s["songname"]), artist: asString(s["singername"]),
                             duration: asDouble(s["duration"]), source: id, ref: hash)
        }
    }

    func fetch(_ c: Candidate) async -> RawLyrics {
        let krc = await HTTPClient.json("http://krcs.kugou.com/search",
                                        [("ver", "1"), ("man", "yes"), ("client", "mobi"), ("hash", c.ref),
                                         ("duration", String(Int(c.duration * 1000)))])
        guard let first = (krc?["candidates"] as? [[String: Any]])?.first else { return RawLyrics() }
        let dl = await HTTPClient.json("http://lyrics.kugou.com/download",
                                       [("ver", "1"), ("client", "pc"), ("id", asString(first["id"])),
                                        ("accesskey", asString(first["accesskey"])), ("fmt", "lrc"), ("charset", "utf8")])
        let content = asString(dl?["content"])
        guard let d = Data(base64Encoded: content), let text = String(data: d, encoding: .utf8) else { return RawLyrics() }
        return RawLyrics(lrc: text)
    }
}
