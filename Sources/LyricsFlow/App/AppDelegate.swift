import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.handle(e) == true ? nil : e
        }
        ShotController.runIfRequested()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Debug keys for the mock player in M1 (no on-screen playback controls by design).
    private func handle(_ e: NSEvent) -> Bool {
        let model = AppModel.shared
        let step: Double = e.modifierFlags.contains(.shift) ? 30 : 5
        switch e.keyCode {
        case 49: model.player.togglePlay()
        case 123: model.player.seek(by: -step)
        case 124: model.player.seek(by: step)
        case 45: model.player.next()
        case 35: model.player.previous()
        case 33: model.settings.timeOffset -= 0.1
        case 30: model.settings.timeOffset += 0.1
        case 46: model.settings.motion = model.settings.motion > 0 ? 0 : 1
        case 3: NSApp.keyWindow?.toggleFullScreen(nil)
        default: return false
        }
        return true
    }
}
