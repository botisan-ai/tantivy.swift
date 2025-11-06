// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// change this to true for local package development
let useLocalFramework = false
let binaryTarget: Target

if useLocalFramework {
    binaryTarget = .binaryTarget(
        name: "TantivyRS",
        // IMPORTANT: Swift packages importing this locally will not be able to
        // import Tantivy unless you specify this as a relative path!
        path: "./build/libtantivy-rs.xcframework"
    )
} else {
    let releaseTag = "0.1.0"
    let releaseChecksum = "16fc0b5e5696288d4b8a4a0a570b9a4385ae218831420ae1979975bbe8df1dec"
    binaryTarget = .binaryTarget(
        name: "TantivyRS",
        url:
        "https://github.com/botisan-ai/tantivy.swift/releases/download/\(releaseTag)/libtantivy-rs.xcframework.zip",
        checksum: releaseChecksum
    )
}

let package = Package(
    name: "TantivySwift",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TantivySwift",
            targets: ["TantivySwift", "TantivyFFI"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        binaryTarget,
        .target(
            name: "TantivySwift", 
            dependencies: ["TantivyFFI"]
        ),
        .target(
            name: "TantivyFFI",
            dependencies: ["TantivyRS"]
        ),
        .testTarget(
            name: "TantivySwiftTests",
            dependencies: ["TantivySwift"]
        ),
    ]
)
