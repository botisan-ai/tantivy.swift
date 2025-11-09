# Tantivy Full Text Search for iOS

This project provides a way to use [Tantivy](https://github.com/quickwit-oss/tantivy), a full-text search engine library written in Rust, in iOS applications. It uses [UniFFI](https://github.com/mozilla/uniffi-rs) to generate Swift bindings.

[demo video](https://assets.botisan.ai/videos/ScreenRecording_11-05-2025%2020-42-43_1.MP4)

## Features

- Create and manage Tantivy indexes, which saves on disk
- safe concurrency with Swift `actor`
- Documents as Swift Codables
- Full-text search results with scores
- Custom Unicode-aware tokenizer by default (works for all languages without configuration)

## Future Plans

- [ ] Schema definition in Swift instead of JSON string
- [ ] More search feature support (facets, filters, aggregations) from Tantivy

## Design Choices

- There should be ways to expose Tantivy more natively to Swift, and with UniFFI, we can even define document structures in Rust and the generated Swift Code works. However, currently I don't think I can make the perfect wrapper in Swift due to my (lack of) expertise in Swift and/or Rust. So most of the communication between Swift and Rust is done via JSON strings, and there is extra overhead on both Swift and Rust sides to serialize/deserialize the data structures.
- There is naming convention difference between Swift and Rust, so it is preferred to use camelCase for field names in Tantivy documents when defining the schema, so that the mapping between Swift Codable structs and Tantivy documents is more natural.
- `Identifiable` protocol is not used for documents yet, because Tantivy does not have a dedicated doc ID field concept (only `DocAddress` which is not exposed). Methods are provided to retrive documents by custom ID fields. We may consider enforcing `Identifiable` protocol in documents in the future.
- By default, a custom Unicode-aware tokenizer is configured into the index, which works for all languages without configuration. While it doesn't have specific language features like Chinese words splitting etc, but it works well enough in vast majority of cases. The goal is to make full-text search work out-of-the-box without extra configuration. We will continue to fine-tune the tokenizer to make it more versatile.

## How to Use

1. Install via Swift Package Manager.
2. You can create a new Rust project and install Tantivy via Cargo (or clone this repo), and use the script in `src/schema-gen.rs` to generate schema JSON string from your Rust document struct definition.
    - if you choose to clone this repo, you can run the script via `cargo run --bin schema-gen`, and it will output the schema JSON string to console and save a copy in the working directory.
3. Check out the test example in `Tests/TantivySwiftTests.swift`, specifically
    - define your document struct conforming to `TantivyIndexDocument` and `Codable`. Paste the generated schema JSON string as the document struct's static `schemaJsonStr` function.
    - be aware that Tantivy returns document fields as [String]'s, so it is best to follow the test example and define custom decode methods in your document struct to convert the fields to appropriate types.
4. Initialize and set up the index in your app, and use the provided methods to add documents and search. (App example is TODO)

## Development

### How to Build

Most of the steps are automated in the `build-ios.sh` script. And the below are the notes for understanding the steps and also specific configurations I have taken to make Tantivy compile.

- There is already `rust-toolchain.toml` available, and just in case you want to do so manually, make sure to add iOS targets for rust:

```sh
# (currently) only aarch64 (M-chip macs) and iOS/mac devices are being targeted in the build script, if you want to extend to more targets, please add them in the build-ios.sh script
rustup target add x86_64-apple-ios
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-darwin
rustup target add x86_64-apple-darwin
rustup target add aarch64-apple-ios-sim
```

- zstd compression feature in Tantivy is diabled, because for iOS builds it couldn't be built.
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


### Custom Tokenizer that is Unicode aware (works for all languages)

- Using https://github.com/unicode-rs/unicode-segmentation because it is more portable.
