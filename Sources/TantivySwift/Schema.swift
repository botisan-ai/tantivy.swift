import Foundation
import TantivyFFI

public protocol TantivySchemaField {
    var fieldName: String { get set }
    func register(with builder: TantivySchemaBuilder)
}

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
}

public protocol TantivyDocument: Codable, Sendable {
    associatedtype CodingKeys: CodingKey
    static func schemaTemplate() -> Self
}

public actor TantivySwiftNativeIndex<Doc: TantivyDocument> {
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
    
    public func index(doc: Doc) throws {
        let jsonData = try JSONEncoder().encode(doc)
        if let jsonStr = String(data: jsonData, encoding: .utf8) {
            try index.indexDoc(docJson: jsonStr)
        }
    }
    
    public func index(docs: [Doc]) throws {
        let jsonData = try JSONEncoder().encode(docs)
        if let jsonStr = String(data: jsonData, encoding: .utf8) {
            try index.indexDocs(docsJson: jsonStr)
        }
    }
    
    public func deleteDoc(idField: Doc.CodingKeys, idValue: String) throws {
        try index.deleteDoc(idField: idField.stringValue, idValue: idValue)
    }
    
    public func docExists(idField: Doc.CodingKeys, idValue: String) throws -> Bool {
        return try index.docExists(idField: idField.stringValue, idValue: idValue)
    }
    
    public func getDoc(idField: Doc.CodingKeys, idValue: String) throws -> Doc? {
        let jsonStr = try index.getDoc(idField: idField.stringValue, idValue: idValue)
        return try JSONDecoder().decode(Doc.self, from: Data(jsonStr.utf8))
    }
    
    public func search(query: TantivySwiftSearchQuery<Doc>) throws -> TantivySearchResults<Doc> 
    where Doc: TantivyIndexDocument {
        let resultsJsonStr = try index.search(query: query.toTantivySearchQuery())
        return try JSONDecoder().decode(
            TantivySearchResults<Doc>.self,
            from: Data(resultsJsonStr.utf8)
        )
    }
}
