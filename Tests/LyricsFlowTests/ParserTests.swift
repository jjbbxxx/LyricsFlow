import Testing
@testable import LyricsFlow

struct LRCParserTests {
    @Test func parsesTimestampsInOrder() {
        let lrc = "[00:12.50]second\n[00:03.00]first\n"
        let r = LRCParser.parse(lrc)
        #expect(r.map(\.1) == ["first", "second"])
        #expect(r[0].0 == 3.0)
        #expect(r[1].0 == 12.5)
    }

    @Test func expandsMultipleStampsOnOneLine() {
        let r = LRCParser.parse("[00:01.00][00:09.00]chorus")
        #expect(r.count == 2)
        #expect(r.map(\.0) == [1.0, 9.0])
    }

    @Test func dropsCreditAndEmptyLines() {
        let lrc = "[00:00.00] 作词 : Someone\n[00:01.00]\n[00:02.00]real line\n[00:03.00]Written by: Someone"
        #expect(LRCParser.parse(lrc).map(\.1) == ["real line"])
    }
}

struct MetaFilterTests {
    @Test func detectsCredits() {
        #expect(MetaFilter.isMeta("作词 : Andrew Goldstein"))
        #expect(MetaFilter.isMeta("作曲：周杰伦"))
        #expect(MetaFilter.isMeta("Producer: Max Martin"))
        #expect(MetaFilter.isMeta("   "))
    }

    @Test func keepsRealLyrics() {
        #expect(!MetaFilter.isMeta("It's beautiful, it's bittersweet"))
        #expect(!MetaFilter.isMeta("缠着我们流连人世间"))
    }
}

struct YRCParserTests {
    private let sample = """
    {"t":0,"c":[{"tx":"作词: "}]}
    [0,1000](0,1000,0) 作词 : Andrew Goldstein
    [9730,2520](9730,300,0)It's (10030,1020,0)beautiful (11050,210,0)it's (11260,990,0)bittersweet
    [12250,2340](12250,210,0)(oh) (12460,450,0)you (12910,500,0)know
    """

    @Test func keepsRealWordTimestamps() throws {
        let lines = YRCParser.parse(sample)
        #expect(lines.count == 2)
        let l = lines[0]
        #expect(l.isWordLevel)
        #expect(l.text == "It's beautiful it's bittersweet")
        let w = try #require(l.words)
        #expect(w.count == 4)
        #expect(w[0].start == 9.73)
        #expect(abs(w[0].end - 10.03) < 1e-9)
        #expect(abs(w[3].end - 12.25) < 1e-9)
    }

    @Test func wordRangesCoverTheText() throws {
        let l = try #require(YRCParser.parse(sample).first)
        #expect(l.wordRanges.first?.lowerBound == 0)
        #expect(l.wordRanges.last?.upperBound == l.text.utf16.count)
    }

    @Test func parenthesisedLyricTextSurvives() throws {
        let l = try #require(YRCParser.parse(sample).last)
        #expect(l.text.hasPrefix("(oh) you"))
    }

    @Test func idsAreSequentialAfterFiltering() {
        #expect(YRCParser.parse(sample).map(\.id) == [0, 1])
    }
}
