// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wirtshaus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Wirtshaus",
            path: "Sources/Wirtshaus"
        )
    ],
    swiftLanguageModes: [.v5]
)
