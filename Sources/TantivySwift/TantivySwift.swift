import Foundation
import TantivyFFI

// protocol that indexable documents must conform to
public protocol TantivyIndexDocument {
    associatedtype CodingKeys: CodingKey
    static func schemaJsonStr() -> String
}

// error type
public enum TantivySwiftError: Error {
    case documentNotFound
}

public struct TantivySwiftSearchQuery<TantivyDoc: Codable & TantivyIndexDocument & Sendable>: Sendable {
    public var queryStr: String
    public var defaultFields: [TantivyDoc.CodingKeys]
    public var fuzzyFields: [TantivySwiftFuzzyField<TantivyDoc>]
    public var topDocLimit: UInt32
    public var lenient: Bool

    func toTantivySearchQuery() -> TantivySearchQuery {
        return TantivySearchQuery(
            queryStr: queryStr,
            defaultFields: defaultFields.map { $0.stringValue },
            fuzzyFields: fuzzyFields.map { $0.toTantivyFuzzyField() },
            topDocLimit: topDocLimit,
            lenient: lenient
        )
    }
}

public struct TantivySwiftFuzzyField<TantivyDoc: Codable & TantivyIndexDocument & Sendable>: Sendable {
    public var field: TantivyDoc.CodingKeys
    public var prefix: Bool
    public var distance: UInt8
    public var transposeCostOne: Bool

    func toTantivyFuzzyField() -> TantivyFuzzyField {
        return TantivyFuzzyField(
            fieldName: field.stringValue,
            prefix: prefix,
            distance: distance,
            transposeCostOne: transposeCostOne
        )
    }
}

// search result struct
// building this struct in Swift so it can use generics
public struct TantivySearchResults<TantivyDoc: Codable & TantivyIndexDocument & Sendable>: Codable, Sendable {
    let count: UInt64
    let docs: [TantivySearchResult<TantivyDoc>]
}

public struct TantivySearchResult<TantivyDoc: Codable & TantivyIndexDocument & Sendable>: Codable, Sendable {
    let score: Float
    let doc: TantivyDoc
}

public actor TantivySwiftIndex<TantivyDoc: Codable & TantivyIndexDocument & Sendable> {
    let index: TantivyIndex

    public init(path: String) throws {
        self.index = try TantivyIndex(path: path, schemaJsonStr: TantivyDoc.schemaJsonStr())
    }

    public func clear() throws {
        try index.clearIndex()
    }

    public func count() -> UInt64 {
        return index.docsCount()
    }

    public func index(doc: TantivyDoc) throws {
        let jsonData = try JSONEncoder().encode(doc)
        if let jsonStr = String(data: jsonData, encoding: .utf8) {
            try index.indexDoc(docJson: jsonStr)
        }
    }

    public func index(docs: [TantivyDoc]) throws {
      let jsonData = try JSONEncoder().encode(docs)
      if let jsonStr = String(data: jsonData, encoding: .utf8) {
          try index.indexDocs(docsJson: jsonStr)
      }
    }

    // TODO: make these methods more Swifty by taking the id field and value as parameters
    public func deleteDoc(idField: TantivyDoc.CodingKeys, idValue: String) throws {
        try index.deleteDoc(idField: idField.stringValue, idValue: idValue)
    }

    public func docExists(idField: TantivyDoc.CodingKeys, idValue: String) throws -> Bool {
        return try index.docExists(idField: idField.stringValue, idValue: idValue)
    }

    public func getDoc(idField: TantivyDoc.CodingKeys, idValue: String) throws -> TantivyDoc? {
        let jsonStr = try index.getDoc(idField: idField.stringValue, idValue: idValue)
        return try JSONDecoder().decode(TantivyDoc.self, from: Data(jsonStr.utf8))
    }

    public func search(query: TantivySwiftSearchQuery<TantivyDoc>) throws -> TantivySearchResults<TantivyDoc> {
        let resultsJsonStr = try index.search(query: query.toTantivySearchQuery())
        return try JSONDecoder().decode(
            TantivySearchResults<TantivyDoc>.self, 
            from: Data(resultsJsonStr.utf8)
        )
    }
}
