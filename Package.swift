// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "DataParser",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v11),
        .tvOS(.v11),
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
