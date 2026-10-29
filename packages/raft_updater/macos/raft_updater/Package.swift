// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "raft_updater",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "raft-updater", targets: ["raft_updater"])
    ],
    dependencies: [
        // Sparkle 2 binary xcframework (includes the Installer/Downloader XPC services).
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(
            name: "raft_updater",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        )
    ]
)
