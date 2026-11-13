// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BookgetApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Bookget", targets: ["BookgetApp"])
    ],
    targets: [
        .executableTarget(
            name: "BookgetApp",
            path: "Sources/BookgetApp"
        )
    ],
    swiftLanguageVersions: [.v5]
)
