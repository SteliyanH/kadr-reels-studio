// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReelsStudio",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .visionOS(.v1)
        // tvOS excluded — kadr-photos requires Photos.framework which isn't on tvOS.
    ],
    products: [
        .library(name: "ReelsStudio", targets: ["ReelsStudio"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SteliyanH/kadr.git", from: "0.9.2"),
        .package(url: "https://github.com/SteliyanH/kadr-ui.git", from: "0.6.0"),
        .package(url: "https://github.com/SteliyanH/kadr-captions.git", from: "0.4.0"),
        .package(url: "https://github.com/SteliyanH/kadr-photos.git", from: "0.4.0"),
    ],
    targets: [
        .target(
            name: "ReelsStudio",
            dependencies: [
                .product(name: "Kadr", package: "kadr"),
                .product(name: "KadrUI", package: "kadr-ui"),
                .product(name: "KadrCaptions", package: "kadr-captions"),
                .product(name: "KadrPhotos", package: "kadr-photos"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "ReelsStudioTests",
            dependencies: ["ReelsStudio"]
        ),
    ]
)
