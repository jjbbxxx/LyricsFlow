import SwiftUI
import AppKit

/// Shown when there is nothing to display: Music closed, stopped, or automation not allowed.
struct IdleView: View {
    let status: PlaybackStatus

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.20), Color(white: 0.09)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 14) {
                Text("LyricsFlow")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                if status == .permissionDenied {
                    Button("打开系统设置") { Self.openAutomationSettings() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(40)
        }
        .ignoresSafeArea()
    }

    private var message: String {
        switch status {
        case .notRunning: return "打开 Apple Music 并开始播放，歌词会自动出现。"
        case .stopped: return "Apple Music 当前没有在播放。"
        case .permissionDenied: return "需要允许 LyricsFlow 读取 Music 的播放状态。\n系统设置 > 隐私与安全性 > 自动化 > LyricsFlow > Music。\n只读取，不会控制播放。"
        case .demo, .active: return ""
        }
    }

    private static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
