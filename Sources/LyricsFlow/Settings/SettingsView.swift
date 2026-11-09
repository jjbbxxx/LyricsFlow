import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Picker("布局", selection: $settings.layoutMode) {
                ForEach(LayoutMode.allCases) { Text($0.label).tag($0) }
            }
            slider("歌词大小", $settings.lyricScale, 0.6...1.6, "%.2fx")
            slider("非当前行模糊", $settings.blurScale, 0...2, "%.2fx")
            slider("歌词时间偏移", $settings.timeOffset, -3...3, "%+.1fs")
            slider("背景动态强度", $settings.motion, 0...1, "%.2f")
        }
        .padding(20)
        .frame(width: 420)
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ fmt: String) -> some View {
        HStack {
            Text(title).frame(width: 100, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: fmt, value.wrappedValue)).monospacedDigit().frame(width: 56, alignment: .trailing)
        }
    }
}
