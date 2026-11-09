import Foundation

struct TrackMeta: Hashable {
    let title: String
    let artist: String
    let album: String
    let duration: Double
}

enum SourcePreference: String, CaseIterable {
    case auto, netease, qq, kugou, lrclib
}
