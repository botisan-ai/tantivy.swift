# CLAUDE.md - AI Development Guide

## Project Overview

tantivy.swift is a Swift wrapper for Tantivy (Rust full-text search engine) using UniFFI for FFI bindings.

## Architecture

```
tantivy.swift/
├── src/lib.rs                    # Rust FFI implementation (UniFFI)
├── Sources/
│   ├── TantivyFFI/tantivy.swift  # Auto-generated UniFFI bindings (DO NOT EDIT)
│   ├── TantivySwift/
│   │   ├── TantivySwift.swift    # Legacy JSON-based API
│   │   ├── Schema.swift          # Property wrappers + native schema API
│   │   └── TantivyDocumentMacro.swift  # Macro declaration
│   └── TantivySwiftMacros/
│       └── TantivyDocumentMacro.swift  # Macro implementation (SwiftSyntax)
├── Tests/TantivySwiftTests/
├── build-ios.sh                  # Build script for Rust → XCFramework
└── Package.swift
```

## Commands

### Build Rust + Generate Swift Bindings
```sh
./build-ios.sh
```
Run this after ANY changes to `src/lib.rs`. This:
1. Compiles Rust code
2. Generates Swift bindings via UniFFI → `Sources/TantivyFFI/tantivy.swift`
3. Builds for iOS/macOS targets
4. Creates XCFramework
5. Updates checksum in Package.swift

### Build Swift Package
```sh
swift build
```

### Run Tests
```sh
swift test
```

### Clean Build
```sh
rm -rf .build && swift build
```

## Local Development Flag

In `Package.swift`, line 8:
```swift
let useLocalFramework = false  // Change to true for local development
```

**IMPORTANT**: 
- Set to `true` when developing locally (uses `./build/libtantivy-rs.xcframework`)
- Set to `false` before committing (uses GitHub release binary)
- Run `./build-ios.sh` first when `useLocalFramework = true`

## Key Files to Know

| File | Purpose |
|------|---------|
| `src/lib.rs` | Rust implementation - all FFI types and functions |
| `Sources/TantivySwift/Schema.swift` | Swift property wrappers (@TextField, @IDField, etc.) |
| `Sources/TantivySwift/TantivyDocumentMacro.swift` | Macro declaration (names generated members) |
| `Sources/TantivySwiftMacros/TantivyDocumentMacro.swift` | Macro implementation (SwiftSyntax) |
| `Sources/TantivyFFI/tantivy.swift` | AUTO-GENERATED - never edit manually |

## @TantivyDocument Macro

The macro generates all Codable boilerplate automatically.

### What It Generates

| Member | Description |
|--------|-------------|
| `CodingKeys` | Enum with case for each `@*Field` property |
| `init(from:)` | Decoder that unwraps Tantivy's `[Value]` array format |
| `encode(to:)` | Encoder with ISO8601 date formatting |
| `schemaTemplate()` | Returns instance with default values for schema extraction |

### Macro Declaration (TantivySwift/TantivyDocumentMacro.swift)
```swift
@attached(member, names: named(schemaTemplate), named(CodingKeys), named(init(from:)), named(encode(to:)))
@attached(extension, conformances: TantivyDocument)
public macro TantivyDocument() = #externalMacro(module: "TantivySwiftMacros", type: "TantivyDocumentMacro")
```

### Adding New Field Type Support
1. Add property wrapper in `Schema.swift`
2. Update `extractFields()` in macro to recognize the new wrapper name
3. Update `generateDecodeLine()` for decoding logic
4. Update `generateEncodeLine()` for encoding logic
5. Update `getDefaultValue()` for schema template

## Development Workflow

### Modifying Rust Code
1. Edit `src/lib.rs`
2. Run `./build-ios.sh`
3. Swift bindings auto-update in `Sources/TantivyFFI/tantivy.swift`
4. Update Swift code to use new bindings
5. Run `swift test`

### Modifying Swift Code Only
1. Ensure `useLocalFramework = true` in Package.swift
2. Edit Swift files
3. Run `swift build` or `swift test`

### Modifying the Macro
1. Edit `Sources/TantivySwiftMacros/TantivyDocumentMacro.swift`
2. If adding new generated members, update the declaration in `Sources/TantivySwift/TantivyDocumentMacro.swift`
3. Run `swift build` (macro recompiles automatically)
4. Run `swift test`

### Adding New Field Types
1. Add Rust struct/enum in `src/lib.rs` with `#[derive(uniffi::Record)]` or `#[uniffi::export]`
2. Add method to `TantivySchemaBuilder` in Rust
3. Run `./build-ios.sh`
4. Add corresponding property wrapper in `Sources/TantivySwift/Schema.swift`
5. Update macro to handle the new wrapper type
6. Add tests

## Common Issues

### "No such module 'TantivyFFI'" in LSP
This is normal when `useLocalFramework = false` and no cached binary exists. Run:
```sh
# Option 1: Use local build
sed -i '' 's/useLocalFramework = false/useLocalFramework = true/' Package.swift
./build-ios.sh

# Option 2: Fetch remote (requires published release)
swift package resolve
```

### "checksum of downloaded artifact does not match"
The local build has different checksum than remote. Either:
- Set `useLocalFramework = true` for local dev
- Or push a new release with updated binary

### Macro Compilation Errors
Macros require SwiftSyntax. If you see "No such module 'SwiftCompilerPlugin'":
```sh
swift package resolve
swift build
```

### "declaration name 'X' is not covered by macro"
The macro is generating a member not listed in its declaration. Update `TantivyDocumentMacro.swift` declaration:
```swift
@attached(member, names: named(schemaTemplate), named(CodingKeys), named(init(from:)), named(encode(to:)), named(NEW_MEMBER))
```

## Testing

Test files:
- `TantivySwiftTests.swift` - Legacy JSON-based API tests
- `NativeSchemaTests.swift` - Native schema API + macro tests

Run specific test:
```sh
swift test --filter "macroGeneratesSchemaTemplate"
```

## Release Checklist

1. Set `useLocalFramework = false` in Package.swift
2. Update version in `Cargo.toml`
3. Run `./build-ios.sh` (updates checksum automatically)
4. Commit changes
5. Create GitHub release with `build/libtantivy-rs.xcframework.zip`
6. Tag matches version in Package.swift
