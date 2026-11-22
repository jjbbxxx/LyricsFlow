import Testing
@testable import LyricsFlow

struct CoverRetryPolicyTests {
    @Test func triesEveryPollAtFirst() {
        #expect(CoverRetryPolicy.shouldTry(elapsed: 0, sinceLastAttempt: 0))
        #expect(CoverRetryPolicy.shouldTry(elapsed: 9.5, sinceLastAttempt: 0.1))
    }

    @Test func backsOffLaterAndGivesUp() {
        #expect(!CoverRetryPolicy.shouldTry(elapsed: 12, sinceLastAttempt: 1))
        #expect(CoverRetryPolicy.shouldTry(elapsed: 12, sinceLastAttempt: 5))
        #expect(!CoverRetryPolicy.shouldTry(elapsed: 121, sinceLastAttempt: 10))
    }

    @Test func keepsPreviousCoverBriefly() {
        #expect(!CoverRetryPolicy.shouldDropCarriedCover(elapsed: 4.9))
        #expect(CoverRetryPolicy.shouldDropCarriedCover(elapsed: 5))
    }

    @Test func identicalBytesFromAnotherAlbumAreStale() {
        let d = TestData.bytes([1, 2, 3])
        #expect(CoverRetryPolicy.isStale(d, previous: d, sameAlbum: false))
        #expect(!CoverRetryPolicy.isStale(d, previous: d, sameAlbum: true))
        #expect(!CoverRetryPolicy.isStale(d, previous: TestData.bytes([9]), sameAlbum: false))
        #expect(!CoverRetryPolicy.isStale(d, previous: nil, sameAlbum: false))
    }
}

struct CatalogSongTests {
    private let json = """
    {"data":[
      {"id":"1","type":"songs","attributes":{"name":"CPR","artistName":"cupcakKe","albumName":"Queen Elizabitch",
        "durationInMillis":208000,"artwork":{"url":"https://is1-ssl.mzstatic.com/image/thumb/a/859720381520_cover.jpg/{w}x{h}{c}.{f}"}}},
      {"id":"2","type":"albums","attributes":{"name":"X","artwork":{"url":"https://x/{w}x{h}bb.jpg"}}},
      {"id":"3","type":"songs","attributes":{"name":"No Art"}}
    ]}
    """

    @Test func parsesOnlySongsWithArtwork() {
        let songs = CatalogSong.parse(TestData.utf8(json))
        #expect(songs.count == 1)
        #expect(songs.first?.album == "Queen Elizabitch")
        #expect(songs.first?.durationSeconds == 208)
        #expect(songs.first?.artworkPrefix == "https://is1-ssl.mzstatic.com/image/thumb/a/859720381520_cover.jpg/")
    }

    @Test func malformedBodyYieldsNothing() {
        #expect(CatalogSong.parse(TestData.utf8("not json")).isEmpty)
        #expect(CatalogSong.parse(TestData.utf8(#"{"data":5}"#)).isEmpty)
    }

    @Test func templateWithoutPlaceholderHasNoPrefix() {
        let s = CatalogSong(name: "a", artist: "b", album: "c", durationSeconds: 0, artworkTemplate: "https://x/y.jpg")
        #expect(s.artworkPrefix == nil)
    }

    @Test func artworkSizeParsesWidth() {
        #expect(ArtworkSize.width(of: "p/800x800bb.jpg", after: "p/") == 800)
        #expect(ArtworkSize.width(of: "p/429x429bb.heic", after: "p/") == 429)
        #expect(ArtworkSize.width(of: "q/800x800bb.jpg", after: "p/") == 0)
    }
}

struct CatalogMatcherTests {
    private func s(_ name: String, _ artist: String, _ album: String, _ dur: Double = 208, art: String = "a") -> CatalogSong {
        CatalogSong(name: name, artist: artist, album: album, durationSeconds: dur, artworkTemplate: art)
    }

    @Test func matchesTitleArtistAlbum() {
        let list = [s("Born Again", "Kim Petras", "Problématique"), s("CPR", "cupcakKe", "Queen Elizabitch", art: "hit")]
        let best = CatalogMatcher.best(list, title: "CPR", artist: "cupcakKe", album: "Queen Elizabitch", duration: 208)
        #expect(best?.artworkTemplate == "hit")
    }

    @Test func newestAcceptableRecordWins() {
        let list = [s("CPR", "cupcakKe", "Queen Elizabitch", art: "new"), s("CPR", "cupcakKe", "Queen Elizabitch", art: "old")]
        #expect(CatalogMatcher.best(list, title: "CPR", artist: "cupcakKe", album: "Queen Elizabitch", duration: 208)?.artworkTemplate == "new")
    }

    @Test func sameTitleOtherAlbumIsRejected() {
        let list = [s("CPR", "cupcakKe", "Last Day of Summer")]
        #expect(CatalogMatcher.best(list, title: "CPR", artist: "cupcakKe", album: "Queen Elizabitch", duration: 208) == nil)
    }

    @Test func durationMismatchIsRejected() {
        let list = [s("CPR", "cupcakKe", "Queen Elizabitch", 150)]
        #expect(CatalogMatcher.best(list, title: "CPR", artist: "cupcakKe", album: "Queen Elizabitch", duration: 208) == nil)
    }

    @Test func featuredArtistStillMatches() {
        let list = [s("RUNWAY", "Lady Gaga & Doechii", "RUNWAY - Single")]
        #expect(CatalogMatcher.best(list, title: "RUNWAY", artist: "Lady Gaga", album: "RUNWAY - Single", duration: 208) != nil)
    }

    @Test func emptyTitleNeverMatches() {
        #expect(CatalogMatcher.best([s("", "a", "b")], title: "", artist: "a", album: "b", duration: 0) == nil)
    }
}
