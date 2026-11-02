// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wirtshausonmac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Wirtshausonmac",
            path: "Sources/Wirtshausonmac"
        )
    ],
    swiftLanguageModes: [.v5]
)
