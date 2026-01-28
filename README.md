# Tantivy Full Text Search for iOS

This project provides a way to use [Tantivy](https://github.com/quickwit-oss/tantivy), a full-text search engine library written in Rust, in iOS applications. It uses [UniFFI](https://github.com/mozilla/uniffi-rs) to generate Swift bindings.

[demo video](https://assets.botisan.ai/videos/ScreenRecording_11-05-2025%2020-42-43_1.MP4)

## Features

- Create and manage Tantivy indexes, which saves on disk
- Safe concurrency with Swift `actor`
- Documents as Swift Codables with property wrapper-based schema definition
- Full-text search results with scores
- Custom Unicode-aware tokenizer by default (works for all languages without configuration)
- Native Rust schema building via FFI (no JSON schema strings needed)
- `@TantivyDocument` macro for zero-boilerplate document definitions

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/botisan-ai/tantivy.swift.git", from: "0.1.3")
]
```

## Quick Start

### 1. Define Your Document

Use property wrappers to define your schema and the `@TantivyDocument` macro to auto-generate all required boilerplate:

```swift
import TantivySwift

@TantivyDocument
struct Article: Sendable {
    @IDField var id: String
    @TextField var title: String
    @TextField var body: String
    @DateField var publishedAt: Date
    @U64Field var viewCount: UInt64
    @BoolField var isPublished: Bool

    init(id: String, title: String, body: String, publishedAt: Date, viewCount: UInt64, isPublished: Bool) {
        self.id = id
        self.title = title
        self.body = body
        self.publishedAt = publishedAt
        self.viewCount = viewCount
        self.isPublished = isPublished
    }
}
```

### 2. Create an Index and Add Documents

```swift
let index = try TantivySwiftIndex<Article>(path: "./my_index")

let article = Article(
    id: "1",
    title: "Hello World",
    body: "This is my first article about Swift and Rust.",
    publishedAt: Date(),
    viewCount: 100,
    isPublished: true
)

try await index.index(doc: article)
```

### 3. Search Documents

```swift
let query = TantivySwiftSearchQuery<Article>(
    queryStr: "swift rust",
    defaultFields: [.title, .body],
    fuzzyFields: [
        TantivySwiftFuzzyField(field: .title, prefix: true, distance: 2),
        TantivySwiftFuzzyField(field: .body, prefix: true, distance: 2),
    ],
    limit: 10
)

let results = try await index.search(query: query)
for result in results.docs {
    print("Score: \(result.score), Title: \(result.doc.title)")
}
```

### Advanced Queries (Query DSL)

Use the query DSL to compose field filters (facets, exact terms, ranges, etc.):

```swift
let textQuery = TantivyQuery.queryString(
    TantivyQueryString(query: "swift", defaultFields: ["title", "body"])
)

let facetQuery = TantivyQuery.term(
    TantivyQueryTerm(name: "category", value: .facet("/tech"))
)

let combined = TantivyQuery.boolean([
    TantivyBooleanClause(occur: .must, query: textQuery),
    TantivyBooleanClause(occur: .must, query: facetQuery),
])

let results = try await index.search(query: combined, limit: 10, offset: 0)
```

## Property Wrappers

| Wrapper | Use Case | Tantivy Type |
|---------|----------|--------------|
| `@IDField` | Unique identifiers (not tokenized) | text (raw tokenizer) |
| `@TextField` | Full-text searchable content | text (unicode tokenizer) |
| `@U64Field` | Unsigned integers | u64 |
| `@I64Field` | Signed integers | i64 |
| `@F64Field` / `@DoubleField` | Floating point numbers | f64 |
| `@BoolField` | Boolean values | bool |
| `@DateField` | Date/time values | date |
| `@BytesField` | Binary data | bytes |
| `@FacetField` | Faceted categories | facet |
| `@JsonField` | JSON object fields | json |

### Property Wrapper Options

Each wrapper accepts configuration options:

```swift
@TextField(tokenizer: .unicode, record: .withFreqsAndPositions, stored: true, fast: false, fieldnorms: true)
var content: String

@U64Field(indexed: true, stored: true, fast: true, fieldnorms: false)
var count: UInt64

@DateField(precision: .milliseconds)
var timestamp: Date
```

## API Reference

### TantivySwiftIndex

| Method | Description |
|--------|-------------|
| `init(path:)` | Create/open an index at the given path |
| `index(doc:)` | Index a single document |
| `index(docs:)` | Index multiple documents |
| `getDoc(idField:idValue:)` | Retrieve a document by ID |
| `deleteDoc(idField:idValue:)` | Delete a document by ID |
| `docExists(idField:idValue:)` | Check if a document exists |
| `search(query:)` | Search for documents |
| `count()` | Get total document count |
| `clear()` | Delete all documents |

## Design Choices

- **Zero Boilerplate**: The `@TantivyDocument` macro generates all Codable conformance, eliminating manual decoder/encoder implementation.
- **Native Schema Building**: Schema is built via native Rust FFI calls instead of JSON strings, providing type safety and better performance.
- **Property Wrappers**: Schema definition uses Swift property wrappers that map directly to Tantivy field types.
- **CamelCase Fields**: Use camelCase for field names to ensure natural mapping between Swift and Tantivy.
- **Unicode Tokenizer**: A custom Unicode-aware tokenizer works for all languages without configuration.

## Development

### Prerequisites

```sh
rustup target add aarch64-apple-ios aarch64-apple-ios-sim aarch64-apple-darwin
```

### Build

```sh
./build-ios.sh
```

This script:
1. Builds the Rust library
2. Generates Swift bindings via UniFFI
3. Builds for iOS targets (device + simulator + macOS)
4. Creates the XCFramework
5. Updates Package.swift with new checksum

### Test

```sh
swift test
```

### Local Development

For local development, set `useLocalFramework = true` in `Package.swift` to use the locally built XCFramework instead of downloading from GitHub releases.

## Custom Tokenizer

Uses [unicode-segmentation](https://github.com/unicode-rs/unicode-segmentation) for portable Unicode-aware tokenization that works across all languages.

## Release

```sh
git tag <version>
git push --tags
gh release create <version> # follow prompt to fill out information
./gh-release.sh <version>
```

## License

[MIT](LICENSE)
