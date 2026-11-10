import AppKit
import Combine

/// Dock icon choices. The files in Resources/Icons are rendered by scripts/make_icon.swift.
/// macOS only lets an app restyle its own Dock icon while it runs; Finder and the .dmg keep `aurora`, which is also the Dock icon whenever nothing is playing.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case cover, aurora, ocean, sunset
    case musicRed = "music-red"
    case monoAuto = "mono-auto"
    case monoLight = "mono-light"
    case monoDark = "mono-dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cover: return "跟随封面（默认）"
        case .aurora: return "极光"
        case .ocean: return "海洋"
        case .sunset: return "日落"
        case .musicRed: return "Music 红"
        case .monoAuto: return "黑白（跟随系统外观）"
        case .monoLight: return "黑白 · 浅色"
        case .monoDark: return "黑白 · 深色"
        }
    }

    /// Resource name of the image to show for the current system appearance.
    func fileName(isDark: Bool) -> String {
        self == .monoAuto ? (isDark ? "mono-dark" : "mono-light") : rawValue
    }
}

/// Keeps the Dock icon in step with the setting, with the system light/dark appearance (automatic
/// black-and-white), and with the cover palette ("follow the cover", cross-faded like the background).
final class AppIconController {
    private static let fade: TimeInterval = 1.4

    private let playback: PlaybackModel
    private var cancellables: Set<AnyCancellable> = []
    private var tween: Timer?
    private var shown = IconArt.fallback

    init(settings: AppSettings, playback: PlaybackModel) {
        self.playback = playback
        let appearance = NSApp.publisher(for: \.effectiveAppearance)
        let trackID = playback.$track.map { $0?.id }.removeDuplicates()
        Publishers.CombineLatest3(settings.$appIcon, appearance, trackID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] choice, appearance, _ in
                self?.apply(choice, isDark: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
            }
            .store(in: &cancellables)
    }

    private func apply(_ choice: AppIconChoice, isDark: Bool) {
        if choice == .cover {
            fade(to: playback.track.map { IconArt.stops(from: $0.palette) } ?? IconArt.fallback)
            return
        }
        tween?.invalidate()
        shown = IconArt.fallback
        let name = choice.fileName(isDark: isDark)
        guard choice != .aurora,
              let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Icons"),
              let image = NSImage(contentsOf: url) else {
            NSApp.applicationIconImage = nil   // back to the bundled icon
            return
        }
        NSApp.applicationIconImage = image
    }

    private func fade(to target: [IconArt.RGB]) {
        tween?.invalidate()
        let from = shown, start = Date()
        tween = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            let p = min(Date().timeIntervalSince(start) / Self.fade, 1)
            let eased = p * p * (3 - 2 * p)
            let stops = IconArt.mix(from, target, eased)
            shown = stops
            NSApp.applicationIconImage = IconArt.image(stops: stops, size: p < 1 ? 512 : 1024)
            if p >= 1 { timer.invalidate() }
        }
    }
}
