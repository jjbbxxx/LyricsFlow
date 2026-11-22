import Foundation

// Command Line Tools ship no `_Testing_Foundation` module, so files importing Testing cannot
// import Foundation as well. Builders for Foundation values live here instead.
enum TestData {
    static func bytes(_ b: [UInt8]) -> Data { Data(b) }
    static func utf8(_ s: String) -> Data { Data(s.utf8) }
}
