import SwiftUI

struct LyricSearchView: View {
    @EnvironmentObject var playback: PlaybackModel
    @StateObject private var model = LyricSearchModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                results.frame(minWidth: 330, idealWidth: 360)
                preview.frame(minWidth: 400)
            }
            Divider()
            footer
        }
        .frame(minWidth: 840, minHeight: 540)
        .onAppear {
            model.reset(for: playback.track)
            if CommandLine.arguments.contains("--auto-search") { model.search() }
        }
        .onChange(of: playback.track?.id) { _ in model.reset(for: playback.track) }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let track = playback.track {
                Text("当前播放：\(track.title) — \(TrackText.subtitle(artist: track.artist, album: track.album))")
                    .font(.callout).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text("当前没有播放").font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                TextField("搜索词，例如：歌名 歌手", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.search() }
                Button("搜索") { model.search() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(playback.track == nil || model.searching)
            }
            HStack(spacing: 14) {
                Text("来源").foregroundStyle(.secondary)
                ForEach(LyricSearchModel.sources) { s in
                    Toggle(s.label, isOn: Binding(
                        get: { model.enabled.contains(s.id) },
                        set: { on in if on { model.enabled.insert(s.id) } else { model.enabled.remove(s.id) } }
                    ))
                    .toggleStyle(.checkbox)
                }
                Spacer()
                if model.searching { ProgressView().controlSize(.small) }
            }
            if let notice = model.notice {
                Text(notice).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(14)
    }

    // MARK: - Results

    private var results: some View {
        Group {
            if model.hits.isEmpty {
                VStack {
                    Spacer()
                    Text(model.searching ? "正在搜索…" : model.searchedOnce ? "没有找到结果，换个搜索词试试。" : "输入搜索词后按回车。")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(model.hits, selection: $model.selection) { hit in
                    row(hit).tag(hit.id)
                }
                .listStyle(.inset)
            }
        }
    }

    private func row(_ hit: LyricsResolver.SearchHit) -> some View {
        let c = hit.candidate
        let precision = model.previews[hit.id]?.precision
        return HStack(spacing: 8) {
            Text(sourceLabel(c.source))
                .font(.caption2).padding(.vertical, 1)
                .frame(width: 58)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(c.title).lineLimit(1)
                Text("\(c.artist) · \(Self.mmss(c.duration))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let precision {
                Text(precision == .word ? "逐字" : "整行")
                    .font(.caption2).foregroundStyle(precision == .word ? Color.accentColor : .secondary)
            }
            Text("\(Int((hit.score * 100).rounded()))%")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Preview

    private var preview: some View {
        Group {
            if let lyrics = model.selectedLyrics, let hit = model.selectedHit {
                VStack(alignment: .leading, spacing: 0) {
                    previewHeader(lyrics, hit)
                    Divider()
                    PreviewLines(lyrics: lyrics)
                }
            } else {
                VStack {
                    Spacer()
                    if model.loadingPreview { ProgressView() }
                    else { Text(model.message ?? "选择左边的一条结果来预览歌词。").foregroundStyle(.secondary) }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func previewHeader(_ lyrics: Lyrics, _ hit: LyricsResolver.SearchHit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hit.candidate.title).font(.headline).lineLimit(1)
            Text("\(sourceLabel(lyrics.source)) · \(lyrics.precision == .word ? "逐字" : "整行") · \(lyrics.lines.count) 行")
                .font(.caption).foregroundStyle(.secondary)
            if let warn = model.versionWarning(for: lyrics, trackDuration: playback.track?.duration ?? 0) {
                Text(warn).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(12)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if model.pinned {
                Label("这首歌已固定一份歌词", systemImage: "pin.fill").font(.callout).foregroundStyle(.secondary)
            } else if let m = model.message {
                Text(m).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if model.pinned {
                Button("恢复自动匹配") { model.restoreAutomatic() }
            }
            Button("使用这份歌词") { model.useSelected(playback: playback) }
                .disabled(model.selectedLyrics == nil)
        }
        .padding(12)
    }

    // MARK: - Helpers

    private func sourceLabel(_ id: String) -> String {
        LyricSearchModel.sources.first { $0.id == id }?.label ?? id
    }

    static func mmss(_ seconds: Double) -> String {
        guard seconds > 0 else { return "--:--" }
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Lyric lines with timestamps; the line at the current playback position is highlighted and kept in view.
private struct PreviewLines: View {
    @EnvironmentObject var playback: PlaybackModel
    let lyrics: Lyrics

    var body: some View {
        ScrollViewReader { proxy in
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                let current = lyrics.index(at: playback.lyricTime(at: ctx.date))
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(lyrics.lines) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(Self.stamp(line.start))
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    .frame(width: 52, alignment: .trailing)
                                Text(line.text)
                                    .fontWeight(line.id == current ? .semibold : .regular)
                                    .foregroundStyle(line.id == current ? Color.primary : Color.secondary)
                                if line.isWordLevel {
                                    Text("逐字").font(.system(size: 9)).foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.vertical, 3).padding(.horizontal, 8)
                            .background(line.id == current ? Color.accentColor.opacity(0.14) : .clear,
                                        in: RoundedRectangle(cornerRadius: 5))
                            .id(line.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: current) { new in
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(new, anchor: .center) }
                }
            }
        }
    }

    private static func stamp(_ t: Double) -> String {
        String(format: "%d:%05.2f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60))
    }
}
