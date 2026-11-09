import Foundation

/// Line-level only for now: QRC (word-level) is encrypted and needs a separate decoder.
struct QQSource: LyricSource {
    let id = "qq"
    private let headers = ["Referer": "https://y.qq.com/"]

    func search(_ query: String) async -> [Candidate] {
        let js = await HTTPClient.json("https://c.y.qq.com/soso/fcgi-bin/client_search_cp",
                                       [("format", "json"), ("n", "8"), ("p", "1"), ("w", query), ("cr", "1"), ("g_tk", "5381")],
                                       headers: headers)
        let list = (((js?["data"] as? [String: Any])?["song"] as? [String: Any])?["list"] as? [[String: Any]]) ?? []
        return list.compactMap { s in
            let mid = asString(s["songmid"])
            guard !mid.isEmpty else { return nil }
            let singers = (s["singer"] as? [[String: Any]] ?? []).map { asString($0["name"]) }.joined(separator: " ")
            let title = asString(s["songname"]).isEmpty ? asString(s["title"]) : asString(s["songname"])
            return Candidate(title: title, artist: singers, duration: asDouble(s["interval"]), source: id, ref: mid)
        }
    }

    func fetch(_ c: Candidate) async -> RawLyrics {
        let js = await HTTPClient.json("https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg",
                                       [("format", "json"), ("nobase64", "1"), ("songmid", c.ref), ("g_tk", "5381"),
                                        ("loginUin", "0"), ("hostUin", "0"), ("inCharset", "utf8"),
                                        ("outCharset", "utf-8"), ("platform", "yqq")], headers: headers)
        var lrc = asString(js?["lyric"])
        if !lrc.isEmpty, !lrc.contains("["), let d = Data(base64Encoded: lrc), let t = String(data: d, encoding: .utf8) {
            lrc = t
        }
        return RawLyrics(lrc: lrc)
    }
}
