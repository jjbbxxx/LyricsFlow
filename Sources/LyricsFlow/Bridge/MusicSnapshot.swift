import Foundation

struct MusicSnapshot: Equatable {
    enum State { case playing, paused }

    let state: State
    let persistentID: String
    let title: String
    let artist: String
    let album: String
    let positionSeconds: Double
    let durationSeconds: Double

    /// Identity used to detect track changes; falls back to text for items without a persistent ID.
    var trackKey: String { persistentID.isEmpty ? "\(title)\u{1F}\(artist)\u{1F}\(album)" : persistentID }

    /// Returns nil for "STOPPED" and anything malformed.
    static func parse(_ raw: String) -> MusicSnapshot? {
        let parts = raw.split(separator: MusicScripts.separator, omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 7 else { return nil }
        let state: State
        switch parts[0].lowercased() {
        case "playing": state = .playing
        case "paused": state = .paused
        default: return nil
        }
        return MusicSnapshot(
            state: state,
            persistentID: parts[1],
            title: parts[2], artist: parts[3], album: parts[4],
            positionSeconds: (Double(parts[5]) ?? 0) / 1000,
            durationSeconds: (Double(parts[6]) ?? 0) / 1000
        )
    }
}
