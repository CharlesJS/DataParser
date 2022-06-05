// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "DataParser",
    products: [
        .library(
            name: "DataParser",
            targets: ["DataParser"]
        ),
        .library(
            name: "DataParser (using Foundation)",
            targets: ["DataParser", "DataParser_Foundation"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DataParser",
            dependencies: ["Internal"]
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
            name: "Internal",
            dependencies: []
        ),
        .target(
            name: "TestHelper",
            dependencies: ["DataParser"]
        )
    ]
)
