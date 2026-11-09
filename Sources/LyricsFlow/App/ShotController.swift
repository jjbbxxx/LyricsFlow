import AppKit
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Visual-acceptance hooks.
///   --shot out.png    [--track N] [--t SEC] [--size WxH] [--layout auto|landscape|portrait] [--pause]
///   --video out.mov   [--track N] [--t SEC] [--size WxH] [--layout ...] [--seconds S]
enum ShotController {
    static func runIfRequested() {
        let args = CommandLine.arguments
        func value(_ key: String) -> String? {
            guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        let shot = value("--shot"), video = value("--video")
        guard shot != nil || video != nil else { return }

        let model = AppModel.shared
        if let l = value("--layout"), let mode = LayoutMode(rawValue: l) { model.settings.layoutMode = mode }
        model.player.select(Int(value("--track") ?? "0") ?? 0, at: Double(value("--t") ?? "0") ?? 0)
        if shot != nil, args.contains("--pause") { model.player.togglePlay() }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard let window = NSApp.windows.first(where: { $0.isVisible }) else { exit(2) }
            if let s = value("--size")?.split(separator: "x").compactMap({ Double($0) }), s.count == 2 {
                place(window, content: NSSize(width: s[0], height: s[1]))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let path = shot { capturePNG(window, to: path); exit(0) }
                if let path = video {
                    VideoRecorder.record(window, to: path, seconds: Double(value("--seconds") ?? "8") ?? 8) { exit(0) }
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
