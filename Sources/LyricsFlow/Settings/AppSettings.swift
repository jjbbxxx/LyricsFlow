import Foundation

enum LayoutMode: String, CaseIterable, Identifiable {
    case auto, landscape, portrait
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "自动"
        case .landscape: return "横屏"
        case .portrait: return "竖屏"
        }
    }
}

final class AppSettings: ObservableObject {
    private let store = UserDefaults.standard

    @Published var lyricScale: Double { didSet { store.set(lyricScale, forKey: "lyricScale") } }
    @Published var blurScale: Double { didSet { store.set(blurScale, forKey: "blurScale") } }
    @Published var timeOffset: Double { didSet { store.set(timeOffset, forKey: "timeOffset") } }
    @Published var motion: Double { didSet { store.set(motion, forKey: "motion") } }
    @Published var layoutMode: LayoutMode { didSet { store.set(layoutMode.rawValue, forKey: "layoutMode") } }

    init() {
        func value(_ key: String, _ def: Double) -> Double {
            UserDefaults.standard.object(forKey: key) as? Double ?? def
        }
        lyricScale = value("lyricScale", 1.0)
        blurScale = value("blurScale", 1.0)
        timeOffset = value("timeOffset", 0)
        motion = value("motion", 1.0)
        layoutMode = LayoutMode(rawValue: UserDefaults.standard.string(forKey: "layoutMode") ?? "") ?? .auto
    }
}
