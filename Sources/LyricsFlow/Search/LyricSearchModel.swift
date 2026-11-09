import Foundation
import SwiftUI

/// State of the lyric search window: query, results, the lyric being previewed, and the pin.
@MainActor
final class LyricSearchModel: ObservableObject {
    struct Source: Identifiable, Hashable {
        let id: String
        let label: String
    }

    static let sources = [
        Source(id: "netease", label: "网易云"),
        Source(id: "qq", label: "QQ 音乐"),
        Source(id: "kugou", label: "酷狗"),
        Source(id: "lrclib", label: "LRCLIB"),
    ]

    @Published var query = ""
    @Published var enabled: Set<String> = Set(sources.map(\.id))
    @Published private(set) var hits: [LyricsResolver.SearchHit] = []
    @Published private(set) var previews: [String: Lyrics] = [:]
    @Published private(set) var searching = false
    @Published private(set) var loadingPreview = false
    @Published private(set) var searchedOnce = false
    @Published private(set) var notice: String?
    @Published private(set) var pinned = false
    @Published private(set) var message: String?
    @Published var selection: String? {
        didSet { if selection != oldValue { loadPreview() } }
    }

    private(set) var trackID: Int?
    private var meta: TrackMeta?
    private var searchTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?

    var selectedHit: LyricsResolver.SearchHit? { hits.first { $0.id == selection } }
    var selectedLyrics: Lyrics? { selection.flatMap { previews[$0] } }

    /// Called when the window opens or the playing track changes.
    func reset(for track: Track?) {
        searchTask?.cancel()
        previewTask?.cancel()
        trackID = track?.id
        meta = track.map { TrackMeta(title: $0.title, artist: $0.artist, album: $0.album, duration: $0.duration) }
        query = track.map { [$0.title, $0.artist].filter { !$0.isEmpty }.joined(separator: " ") } ?? ""
        hits = []
        previews = [:]
        selection = nil
        notice = nil
        message = nil
        searchedOnce = false
        searching = false
        refreshPinned()
    }

    func refreshPinned() {
        guard let meta else { pinned = false; return }
        Task { pinned = await LyricsResolver.shared.isPinned(meta) }
    }

    func search() {
        guard let meta, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searchTask?.cancel()
        searching = true
        notice = nil
        message = nil
        let q = query
        let ids = Self.sources.map(\.id).filter(enabled.contains)
        searchTask = Task {
            let result = await LyricsResolver.shared.search(query: q, for: meta, sourceIDs: ids)
            if Task.isCancelled { return }
            hits = result.hits
            previews = [:]
            selection = result.hits.first?.id
            searching = false
            searchedOnce = true
            if !result.throttled.isEmpty {
                let names = Self.sources.filter { result.throttled.contains($0.id) }.map(\.label).joined(separator: "、")
                notice = "\(names) 暂时被限流，已跳过，稍后再试。"
            }
        }
    }

    private func loadPreview() {
        previewTask?.cancel()
        guard let hit = selectedHit, previews[hit.id] == nil else { loadingPreview = false; return }
        loadingPreview = true
        previewTask = Task {
            let lyrics = await LyricsResolver.shared.preview(hit)
            if Task.isCancelled { return }
            if let lyrics { previews[hit.id] = lyrics }
            else { message = "这一条没有取到可用的同步歌词。" }
            loadingPreview = false
        }
    }

    /// Applies the previewed lyric to the playing track and pins it.
    func useSelected(playback: PlaybackModel) {
        guard let meta, let lyrics = selectedLyrics, let id = trackID else { return }
        Task {
            await LyricsResolver.shared.pin(lyrics, for: meta)
            playback.updateLyrics(trackID: id, lyrics: lyrics)
            pinned = true
            message = "已使用并固定这份歌词。"
        }
    }

    func restoreAutomatic() {
        guard let meta else { return }
        Task {
            await LyricsResolver.shared.unpin(meta)
            pinned = false
            message = "已恢复自动匹配。"
            AppModel.shared.rematchLyrics()
        }
    }

    /// Short note when a candidate looks like another version of the song.
    func versionWarning(for lyrics: Lyrics, trackDuration: Double) -> String? {
        guard trackDuration > 0, let last = lyrics.lines.last else { return nil }
        if !LyricsMatcher.durationOK(lastLineStart: last.start, duration: trackDuration) {
            return "最后一句的时间和歌曲时长对不上，可能是现场版或加长版。"
        }
        return nil
    }
}
