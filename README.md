# Tantivy Full Text Search for iOS

This project provides a way to use [Tantivy](https://github.com/quickwit-oss/tantivy), a full-text search engine library written in Rust, in iOS applications. It uses [UniFFI](https://github.com/mozilla/uniffi-rs) to generate Swift bindings.

## How to Build

- add iOS targets for rust:

```
rustup target add x86_64-apple-ios
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-darwin
rustup target add x86_64-apple-darwin
rustup target add aarch64-apple-ios-sim
```

- Have to disable zstd features in Tantivy for iOS builds because the build config is not correct.
  - `was built for newer 'iOS' version (18.2) than being linked (10.0)`

- Build binary `dylib` (doesn't matter for arch)

```
cargo build --release
```

- bindgen

```
cargo run --release --bin uniffi-bindgen generate --library target/release/libtantivy.dylib --language swift --out-dir out
```

- rename `out/libtantivy.modulemap` to `out/module.modulemap`
  - very important step

- build again for the iOS architectures

```
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
# cargo build --release --target x86_64-apple-ios # (not needed for M1 macs)
```

- Build XCFramework

```
xcodebuild -create-xcframework \
-library target/aarch64-apple-ios/release/libtantivy.a -headers out \
-library target/aarch64-apple-ios-sim/release/libtantivy.a -headers out \
-output ./libtantivy-rs.xcframework
```

- Move the `libtantivy-rs.xcframework` to your iOS project, and also move `out/tantivy.swift` to your iOS project.

- Should be able to reference the Rust code from Swift now.


## Custom Tokenizer that is Unicode aware (works for all languages)

- Using https://github.com/unicode-rs/unicode-segmentation because it is more portable.
