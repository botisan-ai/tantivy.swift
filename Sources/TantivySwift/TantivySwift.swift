import Foundation
import TantivyFFI

// protocol that indexable documents must conform to
protocol TantivyIndexDocument {
  static func schemaJsonStr() -> String
}

// error type
enum TantivySwiftError: Error {
    case documentNotFound
}

// search result struct
// building this struct in Swift so it can use generics
struct TantivySearchResults<TantivyDoc: Codable & TantivyIndexDocument & Sendable>: Codable, Sendable {
    let count: UInt64
    let docs: [TantivySearchResult<TantivyDoc>]
}

struct TantivySearchResult<TantivyDoc: Codable & TantivyIndexDocument & Sendable>: Codable, Sendable {
    let score: Float
    let doc: TantivyDoc
}

actor TantivySwiftIndex<TantivyDoc: Codable & TantivyIndexDocument & Sendable> {
    let index: TantivyIndex

    init(path: String) throws {
        self.index = try TantivyIndex(path: path, schemaJsonStr: TantivyDoc.schemaJsonStr())
    }

    func clear() throws {
        try index.clearIndex()
    }

    func count() -> UInt64 {
        return index.docsCount()
    }

    func index(doc: TantivyDoc) throws {
        let jsonData = try JSONEncoder().encode(doc)
        if let jsonStr = String(data: jsonData, encoding: .utf8) {
            try index.indexDoc(docJson: jsonStr)
        }
    }

    func index(docs: [TantivyDoc]) throws {
      let jsonData = try JSONEncoder().encode(docs)
      if let jsonStr = String(data: jsonData, encoding: .utf8) {
          try index.indexDocs(docsJson: jsonStr)
      }
    }

    func deleteDoc(idField: String, idValue: String) throws {
        try index.deleteDoc(idField: idField, idValue: idValue)
    }

    // TODO: make these methods more Swifty by taking the id field and value as parameters
    func docExists(idField: String, idValue: String) throws -> Bool {
        return try index.docExists(idField: idField, idValue: idValue)
    }

    func getDoc(idField: String, idValue: String) throws -> TantivyDoc? {
        let jsonStr = try index.getDoc(idField: idField, idValue: idValue)
        return try JSONDecoder().decode(TantivyDoc.self, from: Data(jsonStr.utf8))
    }

    func search(query: TantivySearchQuery) throws -> TantivySearchResults<TantivyDoc> {
        let resultsJsonStr = try index.search(query: query)
        return try JSONDecoder().decode(
            TantivySearchResults<TantivyDoc>.self, 
            from: Data(resultsJsonStr.utf8)
        )
    }
}
