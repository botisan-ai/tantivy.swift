// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

// change this to true for local package development
let useLocalFramework = true
let binaryTarget: Target

if useLocalFramework {
    binaryTarget = .binaryTarget(
        name: "TantivyRS",
        // IMPORTANT: Swift packages importing this locally will not be able to
        // import Tantivy unless you specify this as a relative path!
        path: "./build/libtantivy-rs.xcframework"
    )
} else {
    let releaseTag = "0.3.0"
    let releaseChecksum = "5360882c0d9419b1ba0e4f2a4ffb391642d84ab0158a45e54e692addc93dd9a4"
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
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "TantivySwift",
            targets: ["TantivySwift"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        binaryTarget,
        .macro(
            name: "TantivySwiftMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "TantivySwift", 
            dependencies: ["TantivyFFI", "TantivySwiftMacros"]
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
