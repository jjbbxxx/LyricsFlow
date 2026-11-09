import AppKit
import SwiftUI

/// Owns the lyric search window. Created on demand so it never affects the main window at launch.
@MainActor
final class SearchWindowController {
    static let shared = SearchWindowController()
    nonisolated static let title = "搜索歌词"

    private var window: NSWindow?

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: LyricSearchView().environmentObject(AppModel.shared.playback))
            let w = NSWindow(contentViewController: host)
            w.title = Self.title
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.setContentSize(NSSize(width: 920, height: 620))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
