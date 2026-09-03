// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Capt",
    platforms: [.macOS("26.0")],
    targets: [
        // Pure logic: protocols, caption state, session orchestration. No AppKit, so `swift test` is fast.
        .target(
            name: "CaptionCore",
            path: "Sources/CaptionCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The macOS app: audio tap, SpeechAnalyzer engine, overlay panel, menu bar.
        .executableTarget(
            name: "Capt",
            dependencies: ["CaptionCore"],
            path: "Sources/Capt",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CaptionCoreTests",
            dependencies: ["CaptionCore"],
            path: "Tests/CaptionCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
