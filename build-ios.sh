#!/bin/bash

set -ex

rm -rf ./build
rm -rf ./out

# build and bindgen
cargo build
cargo run --bin uniffi-bindgen generate --library ./target/debug/libtantivy.dylib --language swift --out-dir ./out

# rename modulemap
mv ./out/tantivyFFI.modulemap ./out/module.modulemap

# build release for ios (building for non-intel simulators)
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target aarch64-apple-darwin

rm -rf ./build
mkdir -p ./build/Headers
cp ./out/tantivyFFI.h ./build/Headers/
cp ./out/module.modulemap ./build/Headers/

# move generated swift file to swift source
cp ./out/tantivy.swift ./Sources/TantivyFFI/

# build xcframework
xcodebuild -create-xcframework \
-library ./target/aarch64-apple-ios/release/libtantivy.a -headers ./build/Headers \
-library ./target/aarch64-apple-ios-sim/release/libtantivy.a -headers ./build/Headers \
-library ./target/aarch64-apple-darwin/release/libtantivy.a -headers ./build/Headers \
-output ./build/libtantivy-rs.xcframework

ditto -c -k --sequesterRsrc --keepParent ./build/libtantivy-rs.xcframework ./build/libtantivy-rs.xcframework.zip
checksum=$(swift package compute-checksum ./build/libtantivy-rs.xcframework.zip)
version=$(cargo metadata --format-version 1 | jq -r --arg pkg_name "tantivy-swift" '.packages[] | select(.name==$pkg_name) .version')
sed -i "" -E "s/(let releaseTag = \")[^\"]*(\")/\1$version\2/g" ./Package.swift
sed -i "" -E "s/(let releaseChecksum = \")[^\"]*(\")/\1$checksum\2/g" ./Package.swift
