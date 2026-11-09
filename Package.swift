// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LyricsFlow",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LyricsFlow",
            path: "Sources/LyricsFlow"
        )
    ],
    swiftLanguageModes: [.v5]
)
