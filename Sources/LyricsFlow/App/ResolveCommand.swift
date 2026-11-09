import Foundation

/// Debug: LyricsFlow --resolve "title|artist|durationSeconds" [--source netease|qq|kugou|lrclib] [--refresh]
/// Prints what the lyric engine would show and exits.
enum ResolveCommand {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let spec = CommandLineFlags.value("--resolve", in: args) else { return false }
        let parts = spec.components(separatedBy: "|")
        guard parts.count >= 2 else { print("usage: --resolve \"title|artist|duration\""); exit(2) }
        let meta = TrackMeta(title: parts[0], artist: parts[1], album: "", duration: parts.count > 2 ? Double(parts[2]) ?? 0 : 0)
        let source = CommandLineFlags.value("--source", in: args).flatMap(SourcePreference.init(rawValue:)) ?? .auto
        Task {
            let started = Date()
            let lyrics = await LyricsResolver.shared.resolve(meta, source: source, refresh: args.contains("--refresh"))
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            if let lyrics {
                let words = lyrics.lines.filter(\.isWordLevel).count
                print("OK source=\(lyrics.source) precision=\(lyrics.precision) lines=\(lyrics.lines.count) wordLines=\(words) \(ms)ms")
                for l in lyrics.lines.prefix(args.contains("--all") ? 500 : 4) {
                    print(String(format: "  %7.2f  %@%@", l.start, l.text, l.isWordLevel ? "   [\(l.words!.count) words]" : ""))
                }
            } else {
                print("NONE \(ms)ms")
            }
            fflush(stdout)
            exit(0)
        }
        return true
    }
}
