// swift-tools-version:6.0

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
        .library(
            name: "DataParser+Foundation",
            targets: ["DataParser", "DataParser_Foundation"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DataParser",
            dependencies: []
        ),
        .testTarget(
            name: "DataParserTests",
            dependencies: ["TestHelper"]
        ),
        .target(
            name: "DataParser_Foundation",
            dependencies: ["DataParser"]
        ),
        .testTarget(
            name: "DataParserFoundationTests",
            dependencies: ["TestHelper", "DataParser_Foundation"]
        ),
        .target(
            name: "TestHelper",
            dependencies: ["DataParser"]
        )
    ]
)
