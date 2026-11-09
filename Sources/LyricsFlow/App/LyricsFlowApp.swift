import SwiftUI

@main
struct LyricsFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model.player)
                .environmentObject(model.settings)
                .frame(minWidth: 360, minHeight: 360)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 720)

        Settings {
            SettingsView().environmentObject(model.settings)
        }
    }
}
