import AppKit
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Visual-acceptance hooks.
///   --shot out.png    [--live] [--track N] [--t SEC] [--size WxH] [--layout auto|landscape|portrait] [--pause]
///   --video out.mov   [--track N] [--t SEC] [--size WxH] [--layout ...] [--seconds S]
enum ShotController {
    static func runIfRequested() {
        let args = CommandLine.arguments
        func value(_ key: String) -> String? { CommandLineFlags.value(key, in: args) }
        // Debug: contact sheet of the cover-following icon for every demo track.
        if let path = value("--icon-sheet") {
            let tracks = MockLibrary.tracks()
            let cell = 300
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: cell * tracks.count, pixelsHigh: cell, bitsPerSample: 8,
                                       samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            for (i, t) in tracks.enumerated() {
                IconArt.image(stops: IconArt.stops(from: t.palette), size: CGFloat(cell))
                    .draw(in: NSRect(x: i * cell, y: 0, width: cell, height: cell))
            }
            NSGraphicsContext.restoreGraphicsState()
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
            exit(0)
        }
        let shot = value("--shot"), video = value("--video")
        guard shot != nil || video != nil else { return }

        let model = AppModel.shared
        if let l = value("--layout"), let mode = LayoutMode(rawValue: l) { model.settings.layoutOverride = mode }
        if model.isDemo {
            model.playback.selectDemo(Int(value("--track") ?? "0") ?? 0, at: Double(value("--t") ?? "0") ?? 0)
            if shot != nil, args.contains("--pause") { model.playback.toggleDemoPlay() }
            // Debug: jump to the next demo track after N seconds, to capture the cover transition mid-flight.
            if let delay = value("--advance").flatMap({ Double($0) }) {
                let next = (Int(value("--track") ?? "0") ?? 0) + 1
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    model.playback.selectDemo(next, at: Double(value("--t") ?? "0") ?? 0)
                }
            }
            // Debug: swap in another demo track's lyrics (same track id), like picking a lyric in the search window.
            if let n = value("--swap-lyrics").flatMap({ Int($0) }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    guard let id = model.playback.track?.id else { return }
                    model.playback.updateLyrics(trackID: id, lyrics: MockLibrary.tracks()[n].lyrics)
                }
            }
        }

        // A window restored in full screen takes a moment to appear, so poll for it.
        func findWindow(_ attempt: Int, _ found: @escaping (NSWindow) -> Void) {
            if let w = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain && $0.title != SearchWindowController.title })
                ?? NSApp.windows.first(where: { $0.isVisible }) {
                found(w)
            } else if attempt < 30 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { findWindow(attempt + 1, found) }
            } else {
                fputs("no window appeared. windows: \(NSApp.windows.map { "\($0.title)|visible=\($0.isVisible)|main=\($0.canBecomeMain)|\($0.frame)" })\n", stderr)
                exit(2)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            findWindow(0) { window in

            func arrange(_ window: NSWindow) {
                if let s = value("--size")?.split(separator: "x").compactMap({ Double($0) }), s.count == 2 {
                    place(window, content: NSSize(width: s[0], height: s[1]))
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (model.isDemo ? 2.0 : 4.0)) {
                    if let path = shot { capturePNG(window, to: path); exit(0) }
                    if let path = video {
                        VideoRecorder.record(window, to: path, seconds: Double(value("--seconds") ?? "8") ?? 8) { exit(0) }
                    }
                }
            }

            // macOS restores a window that was left in full screen; a full-screen window ignores resizing.
            func start() {
                guard value("--window") == "search" else { arrange(window); return }
                // The search window needs a track on screen to be meaningful, so wait for one first.
                func openSearch(_ attempt: Int) {
                    guard AppModel.shared.playback.track != nil || attempt > 20 else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { openSearch(attempt + 1) }
                        return
                    }
                    MainActor.assumeIsolated { SearchWindowController.shared.show() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        guard let w = NSApp.windows.first(where: { $0.title == SearchWindowController.title && $0.isVisible }) else {
                            fputs("search window not found\n", stderr)
                            exit(3)
                        }
                        arrange(w)
                    }
                }
                openSearch(0)
            }

            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { start() }
            } else {
                start()
            }
            }
        }
    }

    /// Portrait content goes to a portrait display when one is attached.
    private static func place(_ window: NSWindow, content: NSSize) {
        let portrait = content.height > content.width
        let screen = NSScreen.screens.first { portrait ? $0.frame.height > $0.frame.width : $0.frame.width > $0.frame.height } ?? NSScreen.screens[0]
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: content))
        let vis = screen.visibleFrame
        frame.size.width = min(frame.width, vis.width)
        frame.size.height = min(frame.height, vis.height)
        frame.origin = NSPoint(x: vis.midX - frame.width / 2, y: vis.midY - frame.height / 2)
        // A window restored onto another display is clamped to that display, so hop screens first.
        window.setFrameOrigin(NSPoint(x: vis.minX + 40, y: vis.minY + 40))
        window.setFrame(frame, display: true)
    }

    static func image(of window: NSWindow) -> CGImage? {
        CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution])
    }

    private static func capturePNG(_ window: NSWindow, to path: String) {
        guard let img = image(of: window),
              let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { fputs("capture failed\n", stderr); return }
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }
}
