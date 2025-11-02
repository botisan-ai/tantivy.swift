#!/bin/bash

set -ex

rm -rf ./out

# build and bindgen
cargo build
cargo run --bin uniffi-bindgen generate --library ./target/debug/libtantivy.dylib --language swift --out-dir ./out

# rename modulemap
mv ./out/tantivyFFI.modulemap ./out/module.modulemap

# build release for ios (building for non-intel simulators)
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim

rm -rf ./build
mkdir -p ./build/Headers
cp ./out/tantivyFFI.h ./build/Headers/
cp ./out/module.modulemap ./build/Headers/
cp ./out/tantivy.swift ./build/

# build xcframework
xcodebuild -create-xcframework \
-library ./target/aarch64-apple-ios/release/libtantivy.a -headers ./build/Headers \
-library ./target/aarch64-apple-ios-sim/release/libtantivy.a -headers ./build/Headers \
-output ./build/libtantivy-rs.xcframework