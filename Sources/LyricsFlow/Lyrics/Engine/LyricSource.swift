import Foundation

struct RawLyrics {
    var lrc: String = ""
    /// Word-level text when the source provides it (NetEase YRC).
    var yrc: String?
}

protocol LyricSource {
    var id: String { get }
    func search(_ query: String) async -> [Candidate]
    func fetch(_ candidate: Candidate) async -> RawLyrics
}
