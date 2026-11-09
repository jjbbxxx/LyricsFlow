import Foundation

/// Timing of the overflowing title/subtitle scroll: hold at the start, ease in, travel one full
/// period (text plus gap, so the next copy lands exactly where the first began), ease out, repeat.
struct MarqueeMath {
    let period: Double
    let pause: Double
    let duration: Double

    static let speed = 40.0
    static let minimumDuration = 2.5
    static let startPause = 1.5

    static func duration(period: Double) -> Double { max(period / speed, minimumDuration) }

    /// Horizontal offset (0 ... -period) at `elapsed` seconds since the text appeared.
    func offset(elapsed: Double) -> Double {
        let phase = elapsed.truncatingRemainder(dividingBy: pause + duration)
        guard phase > pause else { return 0 }
        let p = min((phase - pause) / duration, 1)
        return -period * Self.easeInOut(p)
    }

    static func easeInOut(_ p: Double) -> Double {
        p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2
    }
}

enum TrackText {
    /// "Artist — Album", like Apple Music's mini player; missing parts are left out.
    static func subtitle(artist: String, album: String) -> String {
        [artist, album]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
    }
}
