// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "DataParser",
    products: [
        .library(
            name: "DataParser",
            targets: ["DataParser"]
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
            dependencies: ["DataParser"]
        ),
    ]
)
