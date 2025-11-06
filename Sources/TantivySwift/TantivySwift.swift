import Foundation
import TantivyFFI

// protocol that indexable documents must conform to
public protocol TantivyIndexDocument {
    static func schemaJsonStr() -> String
}

// error type
public enum TantivySwiftError: Error {
    case documentNotFound
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

    public func deleteDoc(idField: String, idValue: String) throws {
        try index.deleteDoc(idField: idField, idValue: idValue)
    }

    // TODO: make these methods more Swifty by taking the id field and value as parameters
    public func docExists(idField: String, idValue: String) throws -> Bool {
        return try index.docExists(idField: idField, idValue: idValue)
    }

    public func getDoc(idField: String, idValue: String) throws -> TantivyDoc? {
        let jsonStr = try index.getDoc(idField: idField, idValue: idValue)
        return try JSONDecoder().decode(TantivyDoc.self, from: Data(jsonStr.utf8))
    }

    public func search(query: TantivySearchQuery) throws -> TantivySearchResults<TantivyDoc> {
        let resultsJsonStr = try index.search(query: query)
        return try JSONDecoder().decode(
            TantivySearchResults<TantivyDoc>.self, 
            from: Data(resultsJsonStr.utf8)
        )
    }
}
