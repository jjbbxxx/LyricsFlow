import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.handle(e) == true ? nil : e
        }
        if ResolveCommand.runIfRequested() { return }
        ShotController.runIfRequested()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Debug keys. Transport keys only drive the local demo player and never reach Apple Music.
    private func handle(_ e: NSEvent) -> Bool {
        let model = AppModel.shared
        let step: Double = e.modifierFlags.contains(.shift) ? 30 : 5
        switch e.keyCode {
        case 49 where model.isDemo: model.playback.toggleDemoPlay()
        case 123 where model.isDemo: model.playback.seekDemo(by: -step)
        case 124 where model.isDemo: model.playback.seekDemo(by: step)
        case 45 where model.isDemo: model.playback.nextDemo()
        case 35 where model.isDemo: model.playback.previousDemo()
        case 33: model.settings.timeOffset -= 0.1
        case 30: model.settings.timeOffset += 0.1
        case 46: model.settings.motion = model.settings.motion > 0 ? 0 : 1
        case 3: NSApp.keyWindow?.toggleFullScreen(nil)
        default: return false
        }
        return true
    }
}
