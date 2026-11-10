import SwiftUI

extension SourcePreference {
    var label: String {
        switch self {
        case .auto: return "自动（网易云 > QQ > 酷狗 > LRCLIB）"
        case .netease: return "网易云音乐"
        case .qq: return "QQ 音乐"
        case .kugou: return "酷狗音乐"
        case .lrclib: return "LRCLIB"
        }
    }
}

/// All settings live in the menu bar so the lyric window stays free of controls.
struct LyricsCommands: Commands {
    @ObservedObject var settings: AppSettings
    @ObservedObject var playback: PlaybackModel

    var body: some Commands {
        CommandMenu("歌词") {
            Text(currentLyrics)
            Divider()
            Menu("歌词来源") {
                Picker("歌词来源", selection: $settings.lyricSource) {
                    ForEach(SourcePreference.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Button("搜索歌词…") { SearchWindowController.shared.show() }
                .keyboardShortcut("l")
                .disabled(playback.track == nil)
            Button("重新匹配") { AppModel.shared.rematchLyrics() }
                .keyboardShortcut("r")
                .disabled(playback.track == nil || AppModel.shared.isDemo)
            Divider()
            Text(String(format: "时间偏移：%+.1f 秒", settings.timeOffset))
            Button("歌词提前 0.1 秒") { nudgeOffset(-0.1) }.keyboardShortcut("[")
            Button("歌词延后 0.1 秒") { nudgeOffset(0.1) }.keyboardShortcut("]")
            Button("重置时间偏移") { settings.timeOffset = 0 }
        }

        CommandMenu("显示") {
            Menu("布局") {
                Picker("布局", selection: $settings.layoutMode) {
                    ForEach(LayoutMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Menu("图标") {
                Picker("图标", selection: $settings.appIcon) {
                    ForEach(AppIconChoice.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Divider()
            Button("增大歌词") { scale(0.05) }.keyboardShortcut("=")
            Button("减小歌词") { scale(-0.05) }.keyboardShortcut("-")
            Button("默认大小") { settings.lyricScale = 1 }.keyboardShortcut("0")
            Divider()
            Menu("非当前行模糊") {
                Picker("模糊", selection: $settings.blurScale) {
                    Text("关").tag(0.0)
                    Text("弱").tag(0.5)
                    Text("标准").tag(1.0)
                    Text("强").tag(1.5)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Toggle("背景动态效果", isOn: Binding(
                get: { settings.motion > 0 },
                set: { settings.motion = $0 ? 1 : 0 }
            ))
            .keyboardShortcut("m")
        }
    }

    private func nudgeOffset(_ delta: Double) {
        settings.timeOffset = min(max((settings.timeOffset + delta).rounded(toPlaces: 1), -5), 5)
    }

    private func scale(_ delta: Double) {
        settings.lyricScale = min(max((settings.lyricScale + delta).rounded(toPlaces: 2), 0.6), 1.6)
    }

    private var currentLyrics: String {
        guard playback.track != nil else { return "当前没有播放" }
        switch playback.lyricsPhase {
        case .searching: return "正在搜索歌词…"
        case .missing: return "当前来源没有同步歌词"
        case .found:
            let lyrics = playback.track?.lyrics
            let kind = lyrics?.precision == .word ? "逐字" : "逐行"
            return "当前：\(lyrics?.source ?? "")，\(kind)，\(lyrics?.lines.count ?? 0) 行"
        }
    }
}

private extension Double {
    func rounded(toPlaces p: Int) -> Double {
        let m = pow(10.0, Double(p))
        return (self * m).rounded() / m
    }
}
