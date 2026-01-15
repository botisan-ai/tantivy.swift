# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rust-to-Swift wrapper that exposes the Tantivy full-text search engine to iOS/macOS applications using Mozilla's UniFFI for FFI bindings generation.

## Build Commands

```bash
# Full build (generates bindings + builds for all iOS targets + creates XCFramework)
./build-ios.sh

# Run Rust tests
cargo test

# Run Swift tests (requires build-ios.sh to have been run first)
swift test

# Generate schema JSON from Rust struct definitions
cargo run --bin schema-gen

# Manual bindgen (usually run via build-ios.sh)
cargo run --bin uniffi-bindgen generate --library ./target/debug/libtantivy.dylib --language swift --out-dir ./out
```

## Architecture: Rust + Swift via UniFFI

### Layer Structure

```
┌─────────────────────────────────────────┐
│  Swift App Layer                        │
│  (Uses TantivySwiftIndex actor)         │
├─────────────────────────────────────────┤
│  Sources/TantivySwift/TantivySwift.swift│
│  (Swift-native API with generics)       │
├─────────────────────────────────────────┤
│  Sources/TantivyFFI/tantivy.swift       │
│  (UniFFI-generated bindings)            │
├─────────────────────────────────────────┤
│  XCFramework (libtantivy-rs.xcframework)│
│  (Compiled Rust static libraries)       │
├─────────────────────────────────────────┤
│  src/lib.rs                             │
│  (Rust implementation with UniFFI attrs)│
└─────────────────────────────────────────┘
```

### Key Files

- **src/lib.rs**: Rust implementation with `#[uniffi::export]` annotations defining the FFI interface
- **src/uniffi-bindgen.rs**: Binary that invokes UniFFI's Swift code generator
- **Sources/TantivyFFI/tantivy.swift**: Auto-generated Swift bindings (do not edit manually)
- **Sources/TantivySwift/TantivySwift.swift**: Hand-written Swift wrapper providing idiomatic API with generics and actors
- **build-ios.sh**: Build script that orchestrates the entire build pipeline

### Data Flow Pattern

Communication between Swift and Rust uses JSON serialization:
1. Swift `Codable` structs encode to JSON strings
2. JSON strings pass through FFI boundary
3. Rust deserializes with serde_json, processes, serializes results
4. Results return as JSON strings to Swift for decoding

This pattern avoids complex FFI type mappings at the cost of serialization overhead.

## Setting Up a New Rust-to-Swift Package

### 1. Cargo.toml Configuration

```toml
[package]
name = "your-package"
edition = "2024"

[dependencies]
uniffi = { version = "0.30.0", features = ["cli"] }
serde = "1.0"
serde_json = "1.0"
thiserror = "2.0"

[build-dependencies]
uniffi = { version = "0.30.0", features = ["build"] }

[lib]
crate-type = ["cdylib", "staticlib"]
name = "yourlibname"

[[bin]]
name = "uniffi-bindgen"
path = "src/uniffi-bindgen.rs"
```

### 2. Rust FFI Interface (src/lib.rs)

```rust
use uniffi;

#[derive(Debug, thiserror::Error, uniffi::Error)]
#[uniffi(flat_error)]
pub enum YourError {
    #[error("Error: {0}")]
    SomeError(String),
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct YourRecord {
    pub field: String,
}

#[uniffi::export]
pub fn your_function(arg: String) -> Result<String, YourError> {
    Ok(arg)
}

#[uniffi::export]
impl YourStruct {
    #[uniffi::constructor]
    pub fn new() -> Self { ... }

    #[uniffi::method]
    pub fn method(&self) -> Result<(), YourError> { ... }
}

uniffi::setup_scaffolding!();
```

### 3. Bindgen Binary (src/uniffi-bindgen.rs)

```rust
fn main() {
    uniffi::uniffi_bindgen_main()
}
```

### 4. rust-toolchain.toml

```toml
[toolchain]
channel = "stable"
targets = [
    "aarch64-apple-ios",
    "aarch64-apple-ios-sim",
    "aarch64-apple-darwin",
]
components = ["clippy", "rustfmt"]
```

### 5. Build Script Pattern (build-ios.sh)

Key steps:
1. `cargo build` - Build debug dylib for bindgen
2. `cargo run --bin uniffi-bindgen generate --library ./target/debug/libname.dylib --language swift --out-dir ./out` - Generate Swift bindings
3. `mv ./out/nameFFI.modulemap ./out/module.modulemap` - **Critical**: rename modulemap
4. `cargo build --release --target aarch64-apple-ios` (and other targets) - Build release static libs
5. `xcodebuild -create-xcframework` - Create XCFramework from .a files with headers
6. Copy generated .swift file to Sources/YourFFI/

### 6. Package.swift Structure

```swift
let package = Package(
    name: "YourPackage",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(name: "YourPackage", targets: ["YourSwift"]),
    ],
    targets: [
        .binaryTarget(name: "YourRS", path: "./build/libname.xcframework"),
        .target(name: "YourFFI", dependencies: ["YourRS"]),
        .target(name: "YourSwift", dependencies: ["YourFFI"]),
    ]
)
```

### 7. Swift Wrapper Layer

Create a hand-written Swift layer that:
- Uses Swift `actor` for thread-safe concurrency
- Defines protocols for document types (e.g., `TantivyIndexDocument`)
- Handles JSON encoding/decoding with custom `Codable` implementations
- Provides Swift-idiomatic APIs with generics

**Important for Tantivy**: Tantivy returns stored fields as `[String]` arrays. Custom `init(from decoder:)` implementations must handle this by decoding arrays and extracting `.first`.

## iOS Build Considerations

- **zstd issue**: Some Rust crates with zstd compression fail iOS builds due to minimum version conflicts. Disable via feature flags when needed.
- **Targets**: Build for `aarch64-apple-ios` (devices), `aarch64-apple-ios-sim` (Apple Silicon simulators), optionally `x86_64-apple-ios` (Intel simulators)
- **Modulemap naming**: UniFFI generates `nameFFI.modulemap` but Swift packages require `module.modulemap`

## Testing

Swift tests are in `Tests/TantivySwiftTests/`. The test suite demonstrates:
- Index creation and document management
- Custom document struct definitions with `TantivyIndexDocument` protocol
- Search queries with fuzzy field configuration
- Proper `Codable` implementations for Tantivy's array-based field format
- Schema property wrapper tests (`SchemaTests.swift`)
- Macro-generated schema tests

## Schema API (Property Wrapper-based)

The library provides a declarative, type-safe schema API using Swift property wrappers and macros, eliminating the need for manual JSON schema definitions.

### Property Wrappers

| Wrapper | Tantivy Type | Swift Type | Key Options |
|---------|-------------|------------|-------------|
| `@IDField` | text | String | Convenience for raw-tokenized ID fields |
| `@TextField` | text | String | `tokenizer`, `record`, `stored`, `fast`, `fieldnorms` |
| `@UInt64Field` | u64 | UInt64 | `indexed`, `stored`, `fast`, `fieldnorms` |
| `@Int64Field` | i64 | Int64 | `indexed`, `stored`, `fast`, `fieldnorms` |
| `@DoubleField` | f64 | Double | `indexed`, `stored`, `fast`, `fieldnorms` |
| `@DateField` | date | Date | `indexed`, `stored`, `fast`, `precision` |
| `@BoolField` | bool | Bool | `indexed`, `stored`, `fast`, `fieldnorms` |

### Enums

- `Tokenizer`: `.raw`, `.unicode`, `.enStem`, `.whitespace`, `.default`
- `IndexRecordOption`: `.basic`, `.withFreqs`, `.withFreqsAndPositions`
- `DatePrecision`: `.seconds`, `.milliseconds`, `.microseconds`

### Usage with @TantivyDocument Macro (Zero Boilerplate)

```swift
import TantivySwift

@TantivyDocument
struct MyDocument: TantivyIndexDocumentV2 {
    @IDField
    var id: String
    
    @TextField(tokenizer: .unicode, record: .withFreqsAndPositions, stored: true)
    var title: String
    
    @TextField(tokenizer: .unicode, stored: true)
    var body: String
    
    @DateField(indexed: true, stored: true, fast: true, precision: .seconds)
    var createdAt: Date
    
    @DoubleField(stored: true, fast: true)
    var score: Double
}
// The macro auto-generates CodingKeys and schemaTemplate
```

### Usage with Manual schemaTemplate

```swift
struct ManualDoc: TantivyIndexDocumentV2 {
    enum CodingKeys: String, CodingKey {
        case id, name
    }
    
    @IDField var id: String
    @TextField(tokenizer: .unicode, stored: true) var name: String
    
    static var schemaTemplate: Self {
        ManualDoc(id: "", name: "")
    }
}
```

### Architecture

```
┌─────────────────────────────────────────┐
│  Sources/TantivySwift/Schema.swift      │
│  - Property wrappers (@TextField, etc.) │
│  - TantivyFieldSchema protocol          │
│  - TantivySchemaExtractor (Mirror-based)│
│  - TantivyIndexDocumentV2 protocol      │
├─────────────────────────────────────────┤
│  Sources/TantivyMacros/TantivyMacros.swift
│  - @TantivyDocument macro declaration   │
├─────────────────────────────────────────┤
│  Sources/TantivyMacrosPlugin/           │
│  - TantivyDocumentMacro implementation  │
│  - Uses SwiftSyntax for code generation │
└─────────────────────────────────────────┘
```

### How Schema Extraction Works

1. Property wrappers store field configuration (tokenizer, stored, fast, etc.)
2. `TantivySchemaExtractor` uses Swift `Mirror` to reflect over struct properties
3. For each property with a schema-aware wrapper, it extracts field name and options
4. Generates JSON schema array compatible with Tantivy's Rust API
