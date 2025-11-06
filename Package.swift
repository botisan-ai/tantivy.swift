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
    let releaseTag = "0.1.3"
    let releaseChecksum = "ba24c904e07152dc9d1bc42a1662764cbb25a6fb2c60594ed5be0f39dc4b524f"
    binaryTarget = .binaryTarget(
        name: "TantivyRS",
        url:
        "https://github.com/botisan-ai/tantivy.swift/releases/download/\(releaseTag)/libtantivy-rs.xcframework.zip",
        checksum: releaseChecksum
    )
}

let package = Package(
    name: "TantivySwift",
    platforms: [
        // currently supporting iOS 13+ and macOS 10.15+ due to actors
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TantivySwift",
            targets: ["TantivySwift"]
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
