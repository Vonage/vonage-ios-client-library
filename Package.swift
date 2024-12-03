// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VonageClientLibrary",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "VonageClientLibrary",
            targets: ["VonageClientLibrary"]),
    ],
    targets: [
        .target(
            name: "VonageClientLibrary"),
        .testTarget(
            name: "VonageClientLibraryTests",
            dependencies: ["VonageClientLibrary"]),
    ]
)
