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
    let releaseTag = "0.1.3"
    let releaseChecksum = "246294311eaf53c5f990c42d1135f11eec2556856662359d0d9ec8c8a21ddd81"
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
        .library(
            name: "TantivyMacros",
            targets: ["TantivyMacros"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        binaryTarget,
        .target(
            name: "TantivySwift", 
            dependencies: ["TantivyFFI", "TantivyMacros"]
        ),
        .target(
            name: "TantivyFFI",
            dependencies: ["TantivyRS"]
        ),
        .macro(
            name: "TantivyMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "TantivyMacros",
            dependencies: ["TantivyMacrosPlugin"]
        ),
        .testTarget(
            name: "TantivySwiftTests",
            dependencies: ["TantivySwift"]
        ),
    ]
)
