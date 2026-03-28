// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "DataParser",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v4),
        .macCatalyst(.v13)
    ],
    products: [
        .library(
            name: "DataParser",
            targets: ["DataParser"]
        ),
    ],
    traits: [
        "Foundation",
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DataParser",
            dependencies: []
        ),
        .testTarget(
            name: "DataParserTests",
            dependencies: ["DataParser"]
        ),
    ]
)
