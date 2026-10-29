// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
// FlutterFramework dependency is provided through Xcode FRAMEWORK_SEARCH_PATHS.
import PackageDescription

let package = Package(
    name: "app_badge_plus",
    platforms: [
        .macOS("10.14"),
    ],
    products: [
        .library(name: "app-badge-plus", targets: ["app_badge_plus"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "app_badge_plus",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
