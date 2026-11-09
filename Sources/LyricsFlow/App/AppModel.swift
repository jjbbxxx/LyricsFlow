import Foundation
import Combine

final class AppModel {
    static let shared = AppModel()
    let settings: AppSettings
    let playback: PlaybackModel
    private var bridge: MusicBridge?
    private var cancellables: Set<AnyCancellable> = []

    /// Demo mode uses bundled fake tracks and never talks to Apple Music.
    let isDemo: Bool

    private init() {
        let args = CommandLine.arguments
        let settings = AppSettings()
        let playback = PlaybackModel(settings: settings)
        self.settings = settings
        self.playback = playback
        let wantsLiveShot = args.contains("--live")
        let capturing = args.contains { $0 == "--shot" || $0.hasPrefix("--shot=") || $0 == "--video" || $0.hasPrefix("--video=") }
        isDemo = args.contains("--demo") || (capturing && !wantsLiveShot)
        TrackFactory.attachDemoLyrics = args.contains("--demo-lyrics")
        if isDemo {
            playback.enterDemo(tracks: MockLibrary.tracks())
        } else {
            let bridge = MusicBridge(model: playback, settings: settings)
            self.bridge = bridge
            bridge.start()
            settings.$lyricSource.dropFirst().removeDuplicates()
                .sink { _ in bridge.rematch(refresh: false) }
                .store(in: &cancellables)
        }
    }

    func rematchLyrics() { bridge?.rematch(refresh: true) }
}
