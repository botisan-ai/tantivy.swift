import Foundation
import TantivyFFI

public protocol TantivySchemaField {
    var fieldName: String { get set }
    func register(with builder: TantivySchemaBuilder)
}

public protocol TantivyTextFieldMarker {}

@propertyWrapper
public struct TextField<Value: Codable & Sendable>: TantivySchemaField, Codable, Sendable {
    public var wrappedValue: Value
    public var fieldName: String = ""
    
    public var tokenizer: TantivyTokenizer
    public var record: TantivyIndexRecordOption
    public var stored: Bool
    public var fast: Bool
    public var fieldnorms: Bool
    
    public init(
        wrappedValue: Value,
        tokenizer: TantivyTokenizer = .unicode,
        record: TantivyIndexRecordOption = .withFreqsAndPositions,
        stored: Bool = true,
        fast: Bool = false,
        fieldnorms: Bool = true
    ) {
        self.wrappedValue = wrappedValue
        self.tokenizer = tokenizer
        self.record = record
        self.stored = stored
        self.fast = fast
        self.fieldnorms = fieldnorms
    }
    
    public func register(with builder: TantivySchemaBuilder) {
        let options = TextFieldOptions(
            tokenizer: tokenizer,
            record: record,
            stored: stored,
            fast: fast,
            fieldnorms: fieldnorms
        )
        builder.addTextField(name: fieldName, options: options)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
        self.tokenizer = .unicode
        self.record = .withFreqsAndPositions
        self.stored = true
        self.fast = false
        self.fieldnorms = true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension TextField: TantivyTextFieldMarker {}

@propertyWrapper
public struct IDField<Value: Codable & Sendable>: TantivySchemaField, Codable, Sendable {
    public var wrappedValue: Value
    public var fieldName: String = ""
    
    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
    
    public func register(with builder: TantivySchemaBuilder) {
        let options = TextFieldOptions(
            tokenizer: .raw,
            record: .basic,
            stored: true,
            fast: true,
            fieldnorms: false
        )
        builder.addTextField(name: fieldName, options: options)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension IDField: TantivyTextFieldMarker {}

@propertyWrapper
public struct U64Field<Value: Codable & Sendable>: TantivySchemaField, Codable, Sendable {
    public var wrappedValue: Value
    public var fieldName: String = ""
    
    public var indexed: Bool
    public var stored: Bool
    public var fast: Bool
    public var fieldnorms: Bool
    
    public init(
        wrappedValue: Value,
        indexed: Bool = true,
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
    
    public func register(with builder: TantivySchemaBuilder) {
        let options = NumericFieldOptions(
            indexed: indexed,
            stored: stored,
            fast: fast,
            fieldnorms: fieldnorms
        )
        builder.addU64Field(name: fieldName, options: options)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
        self.indexed = true
        self.stored = true
        self.fast = true
        self.fieldnorms = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

@propertyWrapper
public struct I64Field<Value: Codable & Sendable>: TantivySchemaField, Codable, Sendable {
    public var wrappedValue: Value
    public var fieldName: String = ""
    
    public var indexed: Bool
    public var stored: Bool
    public var fast: Bool
    public var fieldnorms: Bool
    
    public init(
        wrappedValue: Value,
        indexed: Bool = true,
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
    
    public func register(with builder: TantivySchemaBuilder) {
        let options = NumericFieldOptions(
            indexed: indexed,
            stored: stored,
            fast: fast,
            fieldnorms: fieldnorms
        )
        builder.addI64Field(name: fieldName, options: options)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
        self.indexed = true
        self.stored = true
        self.fast = true
        self.fieldnorms = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

@propertyWrapper
public struct F64Field<Value: Codable & Sendable>: TantivySchemaField, Codable, Sendable {
    public var wrappedValue: Value
    public var fieldName: String = ""
    
    public var indexed: Bool
    public var stored: Bool
    public var fast: Bool
    public var fieldnorms: Bool
    
    public init(
        wrappedValue: Value,
        indexed: Bool = true,
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
    
    public func register(with builder: TantivySchemaBuilder) {
        let options = NumericFieldOptions(
            indexed: indexed,
            stored: stored,
            fast: fast,
            fieldnorms: fieldnorms
        )
        builder.addF64Field(name: fieldName, options: options)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
        self.indexed = true
        self.stored = true
        self.fast = true
        self.fieldnorms = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

public typealias DoubleField = F64Field

@propertyWrapper
public struct BoolField<Value: Codable & Sendable>: TantivySchemaField, Codable, Sendable {
    public var wrappedValue: Value
    public var fieldName: String = ""
    
    public var indexed: Bool
    public var stored: Bool
    public var fast: Bool
    public var fieldnorms: Bool
    
    public init(
        wrappedValue: Value,
        indexed: Bool = true,
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
    
    public func register(with builder: TantivySchemaBuilder) {
        let options = NumericFieldOptions(
            indexed: indexed,
            stored: stored,
            fast: fast,
            fieldnorms: fieldnorms
        )
        builder.addBoolField(name: fieldName, options: options)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
        self.indexed = true
        self.stored = true
        self.fast = true
        self.fieldnorms = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

@propertyWrapper
public struct DateField<Value: Codable & Sendable>: TantivySchemaField, Codable, Sendable {
    public var wrappedValue: Value
    public var fieldName: String = ""
    
    public var indexed: Bool
    public var stored: Bool
    public var fast: Bool
    public var fieldnorms: Bool
    public var precision: TantivyDatePrecision
    
    public init(
        wrappedValue: Value,
        indexed: Bool = true,
        stored: Bool = true,
        fast: Bool = true,
        fieldnorms: Bool = false,
        precision: TantivyDatePrecision = .milliseconds
    ) {
        self.wrappedValue = wrappedValue
        self.indexed = indexed
        self.stored = stored
        self.fast = fast
        self.fieldnorms = fieldnorms
        self.precision = precision
    }
    
    public func register(with builder: TantivySchemaBuilder) {
        let options = DateFieldOptions(
            indexed: indexed,
            stored: stored,
            fast: fast,
            fieldnorms: fieldnorms,
            precision: precision
        )
        builder.addDateField(name: fieldName, options: options)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
        self.indexed = true
        self.stored = true
        self.fast = true
        self.fieldnorms = false
        self.precision = .milliseconds
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

@propertyWrapper
public struct BytesField<Value: Codable & Sendable>: TantivySchemaField, Codable, Sendable {
    public var wrappedValue: Value
    public var fieldName: String = ""
    
    public var stored: Bool
    public var fast: Bool
    public var indexed: Bool
    
    public init(
        wrappedValue: Value,
        stored: Bool = true,
        fast: Bool = false,
        indexed: Bool = false
    ) {
        self.wrappedValue = wrappedValue
        self.stored = stored
        self.fast = fast
        self.indexed = indexed
    }
    
    public func register(with builder: TantivySchemaBuilder) {
        builder.addBytesField(name: fieldName, stored: stored, fast: fast, indexed: indexed)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
        self.stored = true
        self.fast = false
        self.indexed = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

@propertyWrapper
public struct FacetField<Value: Codable & Sendable>: TantivySchemaField, Codable, Sendable {
    public var wrappedValue: Value
    public var fieldName: String = ""

    public var stored: Bool

    public init(
        wrappedValue: Value,
        stored: Bool = true
    ) {
        self.wrappedValue = wrappedValue
        self.stored = stored
    }

    public func register(with builder: TantivySchemaBuilder) {
        let options = FacetFieldOptions(stored: stored)
        builder.addFacetField(name: fieldName, options: options)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
        self.stored = true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

@propertyWrapper
public struct JsonField<Value: Codable & Sendable>: TantivySchemaField, Codable, Sendable {
    public var wrappedValue: Value
    public var fieldName: String = ""

    public var stored: Bool
    public var indexed: Bool
    public var fast: Bool
    public var tokenizer: TantivyTokenizer
    public var record: TantivyIndexRecordOption
    public var fieldnorms: Bool
    public var expandDots: Bool
    public var fastTokenizer: TantivyTokenizer?

    public init(
        wrappedValue: Value,
        stored: Bool = true,
        indexed: Bool = false,
        fast: Bool = false,
        tokenizer: TantivyTokenizer = .unicode,
        record: TantivyIndexRecordOption = .withFreqsAndPositions,
        fieldnorms: Bool = true,
        expandDots: Bool = false,
        fastTokenizer: TantivyTokenizer? = nil
    ) {
        self.wrappedValue = wrappedValue
        self.stored = stored
        self.indexed = indexed
        self.fast = fast
        self.tokenizer = tokenizer
        self.record = record
        self.fieldnorms = fieldnorms
        self.expandDots = expandDots
        self.fastTokenizer = fastTokenizer
    }

    public func register(with builder: TantivySchemaBuilder) {
        let options = JsonFieldOptions(
            stored: stored,
            indexed: indexed,
            fast: fast,
            tokenizer: tokenizer,
            record: record,
            fieldnorms: fieldnorms,
            expandDots: expandDots,
            fastTokenizer: fastTokenizer
        )
        builder.addJsonField(name: fieldName, options: options)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(Value.self)
        self.stored = true
        self.indexed = false
        self.fast = false
        self.tokenizer = .unicode
        self.record = .withFreqsAndPositions
        self.fieldnorms = true
        self.expandDots = false
        self.fastTokenizer = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

public struct TantivySchemaExtractor {
    
    public static func buildSchema<T>(from document: T) -> TantivySchemaBuilder {
        let builder = TantivySchemaBuilder()
        let mirror = Mirror(reflecting: document)
        
        for child in mirror.children {
            guard let label = child.label else { continue }
            
            let fieldName = label.hasPrefix("_") ? String(label.dropFirst()) : label
            
            if var field = child.value as? TantivySchemaField {
                field.fieldName = fieldName
                field.register(with: builder)
            }
        }
        
        return builder
    }
    
    public static func buildSchema<T: TantivyDocument>(for type: T.Type) -> TantivySchemaBuilder {
        let instance = type.schemaTemplate()
        return buildSchema(from: instance)
    }

    public static func textFieldNames<T>(from document: T) -> [String] {
        let mirror = Mirror(reflecting: document)
        var names: [String] = []

        for child in mirror.children {
            guard let label = child.label else { continue }
            let fieldName = label.hasPrefix("_") ? String(label.dropFirst()) : label
            if child.value is TantivyTextFieldMarker {
                names.append(fieldName)
            }
        }

        return names
    }

    public static func textFieldNames<T: TantivyDocument>(for type: T.Type) -> [String] {
        let instance = type.schemaTemplate()
        return textFieldNames(from: instance)
    }
}

public protocol TantivyDocument: TantivySearchableDocument, Codable, Sendable {
    static func schemaTemplate() -> Self
    func toTantivyDocument() throws -> TantivyDocumentFields
    init(fromFields fields: TantivyDocumentFields) throws
}

public actor TantivySwiftIndex<Doc: TantivyDocument> {
    let index: TantivyIndex
    
    public init(path: String) throws {
        let schemaBuilder = TantivySchemaExtractor.buildSchema(for: Doc.self)
        self.index = try TantivyIndex.newWithSchema(path: path, schemaBuilder: schemaBuilder)
    }
    
    public func clear() throws {
        try index.clearIndex()
    }

    public func count() -> UInt64 {
        return index.docsCount()
    }

    public func add(doc: Doc) throws {
        try index.indexDoc(doc: try doc.toTantivyDocument())
    }

    public func add(docs: [Doc]) throws {
        let nativeDocs = try docs.map { try $0.toTantivyDocument() }
        try index.indexDocs(docs: nativeDocs)
    }

    public func index(doc: Doc) throws {
        try add(doc: doc)
        try commit()
    }

    public func index(docs: [Doc]) throws {
        try add(docs: docs)
        try commit()
    }

    public func commit() throws {
        try index.commit()
    }

    public func deleteDoc(id: DocumentField) throws {
        try index.deleteDoc(id: id)
    }

    public func docExists(id: DocumentField) throws -> Bool {
        return try index.docExists(id: id)
    }

    public func getDoc(id: DocumentField) throws -> Doc? {
        let fields = try index.getDoc(id: id)
        return try Doc(fromFields: fields)
    }

    public func getDocs(ids: [DocumentField]) throws -> [Doc] {
        let fields = try index.getDocsByIds(ids: ids)
        return try fields.map { try Doc(fromFields: $0) }
    }

    public func search(query: TantivyQuery, limit: UInt32 = 10, offset: UInt32 = 0) throws -> TantivySearchResults<Doc> {
        let queryJson = try query.toJson()
        let results = try index.searchDsl(
            queryJson: queryJson,
            topDocLimit: limit,
            topDocOffset: offset
        )
        let docs = try results.docs.map { result in
            TantivySearchResult(score: result.score, doc: try Doc(fromFields: result.doc))
        }
        return TantivySearchResults(count: results.count, docs: docs)
    }

    public func search(query: TantivySwiftSearchQuery<Doc>) throws -> TantivySearchResults<Doc> {
        return try search(query: query.toTantivyQuery(), limit: query.limit, offset: query.offset)
    }
}

public enum TantivyJsonCoding {
    public static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: [], debugDescription: "Invalid UTF-8 data")
            )
        }
        return json
    }

    public static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    public static func decodeIfPresent<T: Decodable>(_ type: T.Type, from json: String?) throws -> T? {
        guard let json else { return nil }
        return try decode(type, from: json)
    }
}

public struct TantivyDocumentFieldMap: Sendable {
    private let values: [String: [FieldValue]]

    public init(_ doc: TantivyDocumentFields) {
        var map: [String: [FieldValue]] = [:]
        for field in doc.fields {
            map[field.name, default: []].append(field.value)
        }
        self.values = map
    }

    public func values(for name: String) -> [FieldValue] {
        return values[name, default: []]
    }

    public func firstValue(for name: String) -> FieldValue? {
        return values(for: name).first
    }

    public func text(_ name: String) -> String? {
        guard case let .text(value) = firstValue(for: name) else { return nil }
        return value
    }

    public func u64(_ name: String) -> UInt64? {
        guard case let .u64(value) = firstValue(for: name) else { return nil }
        return value
    }

    public func i64(_ name: String) -> Int64? {
        guard case let .i64(value) = firstValue(for: name) else { return nil }
        return value
    }

    public func f64(_ name: String) -> Double? {
        guard case let .f64(value) = firstValue(for: name) else { return nil }
        return value
    }

    public func bool(_ name: String) -> Bool? {
        guard case let .bool(value) = firstValue(for: name) else { return nil }
        return value
    }

    public func date(_ name: String) -> Date? {
        guard case let .date(value) = firstValue(for: name) else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(value) / 1_000_000)
    }

    public func bytes(_ name: String) -> Data? {
        guard case let .bytes(value) = firstValue(for: name) else { return nil }
        return value
    }

    public func facet(_ name: String) -> String? {
        guard case let .facet(value) = firstValue(for: name) else { return nil }
        return value
    }

    public func json(_ name: String) -> String? {
        guard case let .json(value) = firstValue(for: name) else { return nil }
        return value
    }
}

public extension DocumentField {
    init<Key: CodingKey>(field: Key, value: FieldValue) {
        self.init(name: field.stringValue, value: value)
    }
}

public extension FieldValue {
    static func from(date value: Date) -> FieldValue {
        let micros = Int64((value.timeIntervalSince1970 * 1_000_000).rounded())
        return .date(micros)
    }
}
