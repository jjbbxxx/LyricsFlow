import Foundation

struct NeteaseSource: LyricSource {
    let id = "netease"
    private let headers = ["Referer": "https://music.163.com"]

    /// NetEase answers `{"code":405,"msg":"操作频繁，请稍候再试"}` when it throttles a client.
    private func isRateLimited(_ js: [String: Any]?) async -> Bool {
        guard let js, asDouble(js["code"]) == 405 || asString(js["msg"]).contains("频繁") else { return false }
        await SourceHealth.shared.tripRateLimit(id)
        return true
    }

    func search(_ query: String) async -> [Candidate] {
        let js = await HTTPClient.json("https://music.163.com/api/search/get/web",
                                       [("s", query), ("type", "1"), ("limit", "8"), ("offset", "0")], headers: headers)
        if await isRateLimited(js) { return [] }
        let songs = ((js?["result"] as? [String: Any])?["songs"] as? [[String: Any]]) ?? []
        if !songs.isEmpty { await SourceHealth.shared.recordSuccess(id) }
        return songs.compactMap { s in
            let sid = asString(s["id"])
            guard !sid.isEmpty else { return nil }
            let artists = (s["artists"] as? [[String: Any]] ?? []).map { asString($0["name"]) }.joined(separator: " ")
            return Candidate(title: asString(s["name"]), artist: artists,
                             duration: asDouble(s["duration"]) / 1000, source: id, ref: sid)
        }
    }

    func fetch(_ c: Candidate) async -> RawLyrics {
        let js = await HTTPClient.json("https://music.163.com/api/song/lyric",
                                       [("os", "pc"), ("id", c.ref), ("lv", "-1"), ("kv", "-1"), ("tv", "-1"), ("yv", "-1")],
                                       headers: headers)
        if await isRateLimited(js) { return RawLyrics() }
        let lrc = asString((js?["lrc"] as? [String: Any])?["lyric"])
        let yrc = asString((js?["yrc"] as? [String: Any])?["lyric"])
        return RawLyrics(lrc: lrc, yrc: yrc.isEmpty ? nil : yrc)
    }
}
