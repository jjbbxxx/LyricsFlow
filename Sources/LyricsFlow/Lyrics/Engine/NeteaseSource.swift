import Foundation

struct NeteaseSource: LyricSource {
    let id = "netease"
    private let headers = ["Referer": "https://music.163.com"]

    func search(_ query: String) async -> [Candidate] {
        let js = await HTTPClient.json("https://music.163.com/api/search/get/web",
                                       [("s", query), ("type", "1"), ("limit", "8"), ("offset", "0")], headers: headers)
        let songs = ((js?["result"] as? [String: Any])?["songs"] as? [[String: Any]]) ?? []
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
        let lrc = asString((js?["lrc"] as? [String: Any])?["lyric"])
        let yrc = asString((js?["yrc"] as? [String: Any])?["lyric"])
        return RawLyrics(lrc: lrc, yrc: yrc.isEmpty ? nil : yrc)
    }
}
