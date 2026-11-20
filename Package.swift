// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LumaSdk",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
    ],
    products: [
        .library(name: "LumaSdk", targets: ["LumaSdk"]),
    ],
    targets: [
        .target(
            name: "LumaSdk",
            path: "Sources/LumaSdk"
        ),
        .testTarget(
            name: "LumaSdkTests",
            dependencies: ["LumaSdk"],
            path: "Tests/LumaSdkTests"
        ),
    ]
)
