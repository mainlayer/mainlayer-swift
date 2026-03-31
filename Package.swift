// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mainlayer",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Mainlayer",
            targets: ["Mainlayer"]
        )
    ],
    targets: [
        .target(
            name: "Mainlayer",
            path: "Sources/Mainlayer"
        ),
        .testTarget(
            name: "MainlayerTests",
            dependencies: ["Mainlayer"],
            path: "Tests/MainlayerTests"
        )
    ]
)
