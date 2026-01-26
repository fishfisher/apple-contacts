// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "apple-contacts",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "apple-contacts",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ]
        ),
    ]
)
