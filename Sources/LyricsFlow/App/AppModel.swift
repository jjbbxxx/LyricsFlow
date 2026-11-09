import Foundation

final class AppModel {
    static let shared = AppModel()
    let settings: AppSettings
    let player: MockPlayer

    private init() {
        let settings = AppSettings()
        self.settings = settings
        self.player = MockPlayer(tracks: MockLibrary.tracks(), settings: settings)
    }
}
