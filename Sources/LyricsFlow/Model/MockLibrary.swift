import Foundation

enum MockLibrary {
    static func tracks() -> [Track] {
        [echoes(), nightFlight(), staticBloom(), paperSky()]
    }

    private static func make(_ id: Int, _ title: String, _ artist: String, _ album: String, _ dur: Double,
                             _ kind: CoverArt.Kind, _ lines: [LyricLine], source: String) -> Track {
        let cover = CoverArt.make(kind)
        return Track(id: id, title: title, artist: artist, album: album, duration: dur, cover: cover,
                     palette: PaletteExtractor.extract(from: cover), lyrics: Lyrics(source: source, lines: lines))
    }

    private static func echoes() -> Track {
        let s = LyricBuilder.spaced
        let lines = [
            s(0, 2.0, "the|0.35 city|0.45 glows|0.6 in|0.25 the|0.25 distance|1.1"),
            s(1, 6.2, "i|0.2 can|0.35 hear|0.45 the|0.25 rain|0.7 again|1.7"),
            s(2, 10.8, "you|0.3 know|0.4 you|0.3 can|0.35 take|0.5 me|0.3 anywhere|1.5"),
            s(3, 15.6, "we|0.3 will|0.35 remember|0.8 every|0.55 moment|1.6"),
            s(4, 20.5, "until|0.5 the|0.3 morning|1.0 finds|0.5 us|0.4 here|1.7"),
            s(5, 26.0, "the|0.3 colors|0.6 fade|0.6 into|0.4 the|0.25 night|1.9"),
            s(6, 31.5, "and|0.3 every|0.5 echo|0.8 turns|0.5 to|0.25 light|2.1"),
            s(7, 37.5, "hold|0.5 on|0.5 to|0.3 the|0.3 sound|1.2 of|0.3 us|1.7"),
            s(8, 43.0, "when|0.4 the|0.25 silence|0.9 comes|0.6 around|1.1"),
            s(9, 48.0, "we|0.3 will|0.4 sing|0.8 it|0.3 back|0.6 again|2.3"),
        ]
        return make(0, "Between The Echoes", "Lyrics Flow · Demo", "Visual Demo", 56, .blue, lines, source: "mock-word")
    }

    private static func nightFlight() -> Track {
        let c = LyricBuilder.unspaced, s = LyricBuilder.spaced
        let lines = [
            c(0, 2.0, "夜|0.4 色|0.5 落|0.5 在|0.4 窗|0.5 台|1.0"),
            c(1, 6.5, "城|0.4 市|0.5 的|0.3 灯|0.5 慢|0.5 慢|0.5 亮|1.2"),
            c(2, 11.5, "我|0.4 听|0.5 见|0.5 远|0.5 处|0.5 的|0.4 回|0.5 声|1.4"),
            c(3, 16.5, "风|0.4 把|0.4 名|0.5 字|0.5 带|0.5 向|0.5 海|0.6 面|1.6"),
            c(4, 22.0, "所|0.35 有|0.4 沉|0.6 默|0.8 都|0.4 有|0.4 光|1.8"),
            c(5, 27.5, "再|0.4 一|0.4 次|0.5 想|0.5 起|0.5 来|1.5"),
            c(6, 32.5, "应|0.4 该|0.5 要|0.5 怎|0.5 么|0.5 笑|2.0"),
            s(7, 38.5, "the|0.3 day|0.4 you|0.3 went|0.5 away|1.3"),
            c(8, 43.5, "喧|0.3 闹|0.3 的|0.3 街|0.5 没|0.4 发|0.4 现|0.4 我|0.4 的|0.4 泪|0.5 被|0.4 遗|0.4 忘|0.4 在|0.4 街|0.4 角|1.4"),
            c(9, 50.0, "有|0.4 一|0.4 天|0.6 也|0.4 许|0.5 我|0.4 能|0.4 把|0.4 自|0.4 己|0.4 治|0.4 好|1.6"),
        ]
        return make(1, "夜航", "示例歌手", "演示专辑", 58, .gold, lines, source: "mock-word-cn")
    }

    private static func staticBloom() -> Track {
        let lines = LyricBuilder.lrc([
            (3.0, "black and white and nothing in between"),
            (7.5, "I keep the silence folded in my sleeve"),
            (12.0, "灯光熄灭以后 房间变得很安静"),
            (16.5, "static blooms across the window glass"),
            (21.0, "我数着窗外经过的每一辆车"),
            (25.5, "nothing here is ever really lost"),
            (30.0, "only waiting for the signal to return"),
            (35.0, "回声在墙上慢慢变轻"),
            (40.0, "and when the morning comes I will be gone"),
            (45.5, "留下一点点噪音"),
        ])
        return make(2, "Static Bloom", "Mono Demo", "Line Sync Only", 54, .mono, lines, source: "mock-lrc")
    }

    private static func paperSky() -> Track {
        let lines = LyricBuilder.lrc([
            (3.0, "a paper sky above the paper town"),
            (7.5, "we fold the clouds into small boats"),
            (12.0, "纸一样的天空 轻轻放在手心"),
            (16.5, "the light is almost white again"),
            (21.0, "我们把名字写在最薄的风里"),
            (25.5, "nothing weighs a thing up here"),
            (30.0, "and every word is easy to read"),
            (35.0, "白色的海 白色的岸"),
            (40.0, "so let the whole page turn"),
            (45.5, "直到天亮"),
        ])
        return make(3, "Paper Sky", "Pale Demo", "Near White Cover", 54, .pale, lines, source: "mock-lrc")
    }
}
