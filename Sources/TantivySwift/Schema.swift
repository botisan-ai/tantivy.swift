import Foundation
@_exported import TantivyMacros

// MARK: - Core Enums (matching Tantivy's Rust API)

/// Tokenizer options for text fields
public enum Tokenizer: String, Codable, Sendable {
    /// No tokenization - treats the entire field as a single token (good for IDs, exact match)
    case raw = "raw"
    /// Default tokenizer with basic word splitting
    case `default` = "default"
    /// Unicode-aware tokenizer with proper word boundaries
    case unicode = "unicode"
    /// English stemming tokenizer (reduces words to their root form)
    case enStem = "en_stem"
    /// Simple whitespace tokenizer
    case whitespace = "whitespace"
}

/// Controls what information is recorded in the index for text fields
public enum IndexRecordOption: String, Codable, Sendable {
    /// Only records document IDs (smallest index, no phrase queries)
    case basic = "basic"
    /// Records document IDs and term frequencies
    case withFreqs = "freq"
    /// Records document IDs, frequencies, and positions (enables phrase queries)
    case withFreqsAndPositions = "position"
}

/// Precision for date/time fields in fast field storage
public enum DatePrecision: String, Codable, Sendable {
    case seconds = "seconds"
    case milliseconds = "milliseconds"
    case microseconds = "microseconds"
}

// MARK: - Schema Field Protocol

/// Protocol that all schema-aware property wrappers conform to
public protocol TantivyFieldSchema {
    /// The Tantivy field type name (e.g., "text", "u64", "date")
    static var tantivyType: String { get }
    
    /// Generates the JSON options dictionary for this field
    func toSchemaOptions() -> [String: Any]
}

// MARK: - Text Field Property Wrapper

/// Property wrapper for text fields in a Tantivy index
///
/// Usage:
/// ```swift
/// struct MyDocument: TantivyIndexDocument {
///     @TextField(tokenizer: .raw, stored: true)
///     var id: String
///
///     @TextField(tokenizer: .unicode, record: .withFreqsAndPositions, stored: true)
///     var title: String
/// }
/// ```
@propertyWrapper
public struct TextField: TantivyFieldSchema, Sendable, Codable {
    public static var tantivyType: String { "text" }
    
    public var wrappedValue: String
    
    public let tokenizer: Tokenizer
    public let record: IndexRecordOption
    public let fieldnorms: Bool
    public let stored: Bool
    public let fast: Bool
    
    public init(
        wrappedValue: String = "",
        tokenizer: Tokenizer = .unicode,
        record: IndexRecordOption = .withFreqsAndPositions,
        stored: Bool = true,
        fast: Bool = false,
        fieldnorms: Bool = true
    ) {
        self.wrappedValue = wrappedValue
        self.tokenizer = tokenizer
        self.record = record
        self.fieldnorms = fieldnorms
        self.stored = stored
        self.fast = fast
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(String.self)
        self.tokenizer = .unicode
        self.record = .withFreqsAndPositions
        self.fieldnorms = true
        self.stored = true
        self.fast = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
    
    public func toSchemaOptions() -> [String: Any] {
        var options: [String: Any] = [
            "stored": stored,
            "fast": fast
        ]
        
        options["indexing"] = [
            "record": record.rawValue,
            "fieldnorms": fieldnorms,
            "tokenizer": tokenizer.rawValue
        ]
        
        return options
    }
}

// MARK: - ID Field (convenience for raw text fields)

/// Property wrapper for ID fields - convenience for raw tokenized text fields
///
/// Usage:
/// ```swift
/// struct MyDocument: TantivyIndexDocument {
///     @IDField
///     var id: String
/// }
/// ```
@propertyWrapper
public struct IDField: TantivyFieldSchema, Sendable, Codable {
    public static var tantivyType: String { "text" }
    
    public var wrappedValue: String
    
    public let stored: Bool
    
    public init(
        wrappedValue: String = "",
        stored: Bool = true
    ) {
        self.wrappedValue = wrappedValue
        self.stored = stored
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(String.self)
        self.stored = true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
    
    public func toSchemaOptions() -> [String: Any] {
        return [
            "stored": stored,
            "fast": false,
            "indexing": [
                "record": IndexRecordOption.basic.rawValue,
                "fieldnorms": true,
                "tokenizer": Tokenizer.raw.rawValue
            ]
        ]
    }
}

// MARK: - Numeric Field Property Wrappers

@propertyWrapper
public struct UInt64Field: TantivyFieldSchema, Sendable, Codable {
    public static var tantivyType: String { "u64" }
    
    public var wrappedValue: UInt64
    
    public let indexed: Bool
    public let stored: Bool
    public let fast: Bool
    public let fieldnorms: Bool
    
    public init(
        wrappedValue: UInt64 = 0,
        indexed: Bool = true,
        stored: Bool = true,
        fast: Bool = false,
        fieldnorms: Bool = false
    ) {
        self.wrappedValue = wrappedValue
        self.indexed = indexed
        self.stored = stored
        self.fast = fast
        self.fieldnorms = fieldnorms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(UInt64.self)
        self.indexed = true
        self.stored = true
        self.fast = false
        self.fieldnorms = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
    
    public func toSchemaOptions() -> [String: Any] {
        return [
            "indexed": indexed,
            "stored": stored,
            "fast": fast,
            "fieldnorms": fieldnorms
        ]
    }
}

@propertyWrapper
public struct Int64Field: TantivyFieldSchema, Sendable, Codable {
    public static var tantivyType: String { "i64" }
    
    public var wrappedValue: Int64
    
    public let indexed: Bool
    public let stored: Bool
    public let fast: Bool
    public let fieldnorms: Bool
    
    public init(
        wrappedValue: Int64 = 0,
        indexed: Bool = true,
        stored: Bool = true,
        fast: Bool = false,
        fieldnorms: Bool = false
    ) {
        self.wrappedValue = wrappedValue
        self.indexed = indexed
        self.stored = stored
        self.fast = fast
        self.fieldnorms = fieldnorms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Int64.self)
        self.indexed = true
        self.stored = true
        self.fast = false
        self.fieldnorms = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
    
    public func toSchemaOptions() -> [String: Any] {
        return [
            "indexed": indexed,
            "stored": stored,
            "fast": fast,
            "fieldnorms": fieldnorms
        ]
    }
}

@propertyWrapper
public struct DoubleField: TantivyFieldSchema, Sendable, Codable {
    public static var tantivyType: String { "f64" }
    
    public var wrappedValue: Double
    
    public let indexed: Bool
    public let stored: Bool
    public let fast: Bool
    public let fieldnorms: Bool
    
    public init(
        wrappedValue: Double = 0.0,
        indexed: Bool = false,
        stored: Bool = true,
        fast: Bool = true,
        fieldnorms: Bool = false
    ) {
        self.wrappedValue = wrappedValue
        self.indexed = indexed
        self.stored = stored
        self.fast = fast
        self.fieldnorms = fieldnorms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Double.self)
        self.indexed = false
        self.stored = true
        self.fast = true
        self.fieldnorms = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
    
    public func toSchemaOptions() -> [String: Any] {
        return [
            "indexed": indexed,
            "stored": stored,
            "fast": fast,
            "fieldnorms": fieldnorms
        ]
    }
}

// MARK: - Date Field Property Wrapper

@propertyWrapper
public struct DateField: TantivyFieldSchema, Sendable, Codable {
    public static var tantivyType: String { "date" }
    
    public var wrappedValue: Date
    
    public let indexed: Bool
    public let stored: Bool
    public let fast: Bool
    public let fieldnorms: Bool
    public let precision: DatePrecision
    
    public init(
        wrappedValue: Date = Date(),
        indexed: Bool = true,
        stored: Bool = true,
        fast: Bool = false,
        fieldnorms: Bool = true,
        precision: DatePrecision = .seconds
    ) {
        self.wrappedValue = wrappedValue
        self.indexed = indexed
        self.stored = stored
        self.fast = fast
        self.fieldnorms = fieldnorms
        self.precision = precision
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Date.self)
        self.indexed = true
        self.stored = true
        self.fast = false
        self.fieldnorms = true
        self.precision = .seconds
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
    
    public func toSchemaOptions() -> [String: Any] {
        return [
            "indexed": indexed,
            "stored": stored,
            "fast": fast,
            "fieldnorms": fieldnorms,
            "precision": precision.rawValue
        ]
    }
}

// MARK: - Bool Field Property Wrapper

@propertyWrapper
public struct BoolField: TantivyFieldSchema, Sendable, Codable {
    public static var tantivyType: String { "bool" }
    
    public var wrappedValue: Bool
    
    public let indexed: Bool
    public let stored: Bool
    public let fast: Bool
    public let fieldnorms: Bool
    
    public init(
        wrappedValue: Bool = false,
        indexed: Bool = true,
        stored: Bool = true,
        fast: Bool = false,
        fieldnorms: Bool = false
    ) {
        self.wrappedValue = wrappedValue
        self.indexed = indexed
        self.stored = stored
        self.fast = fast
        self.fieldnorms = fieldnorms
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Bool.self)
        self.indexed = true
        self.stored = true
        self.fast = false
        self.fieldnorms = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
    
    public func toSchemaOptions() -> [String: Any] {
        return [
            "indexed": indexed,
            "stored": stored,
            "fast": fast,
            "fieldnorms": fieldnorms
        ]
    }
}

// MARK: - Schema Extraction Utilities

public struct TantivySchemaExtractor {
    
    public static func generateSchemaJSON<T>(for type: T.Type) -> String where T: TantivyIndexDocumentV2 {
        let instance = T.schemaTemplate
        let mirror = Mirror(reflecting: instance)
        
        var fields: [[String: Any]] = []
        
        for child in mirror.children {
            guard let label = child.label else { continue }
            
            let fieldName = label.hasPrefix("_") ? String(label.dropFirst()) : label
            
            if let schemaField = child.value as? TantivyFieldSchema {
                let fieldType = Swift.type(of: schemaField)
                
                let fieldDict: [String: Any] = [
                    "name": fieldName,
                    "type": fieldType.tantivyType,
                    "options": schemaField.toSchemaOptions()
                ]
                
                fields.append(fieldDict)
            }
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: fields, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "[]"
        }
        
        return jsonString
    }
}

// MARK: - Updated Protocol

public protocol TantivyIndexDocumentV2: Codable, Sendable {
    associatedtype CodingKeys: CodingKey
    static var schemaTemplate: Self { get }
}

extension TantivyIndexDocumentV2 {
    public static func schemaJsonStr() -> String {
        return TantivySchemaExtractor.generateSchemaJSON(for: Self.self)
    }
}
