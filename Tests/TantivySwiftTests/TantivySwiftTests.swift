import Foundation
import Testing
@testable import TantivySwift
import TantivyFFI

struct ExampleIndexDoc: Codable, TantivyIndexDocument, Sendable {
    // custom coding keys
    enum CodingKeys: String, CodingKey {
        // we recommend using camelCase for tantivy doc field names
        // but if you want to map to different JSON keys, you can do so here

        // case docId = "doc_id"

        case docId
        case title
        case body
    }

    let docId: String
    let title: String
    let body: String

    // since we need a custom decoder to handle Tantivy's stored field format
    // we provide a default constructor
    init(docId: String, title: String, body: String) {
        self.docId = docId
        self.title = title
        self.body = body
    }

    init(from decoder: Decoder) throws {
        // Tantivy returns stored fields as arrays, even for single-valued fields
        let container = try decoder.container(keyedBy: CodingKeys.self)
        docId = try container.decode([String].self, forKey: .docId).first ?? ""
        title = try container.decode([String].self, forKey: .title).first ?? ""
        body = try container.decode([String].self, forKey: .body).first ?? ""
    }

    func encode(to encoder: Encoder) throws {
        // custom encoder in case we need to map dates etc
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(docId, forKey: .docId)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
    }

    // we want to provide a better DX for schema definition
    // but for now it is easiest to serialize with Rust code and paste here
    static func schemaJsonStr() -> String {
        """
        [
        {
            "name": "docId",
            "type": "text",
            "options": {
            "indexing": {
                "record": "basic",
                "fieldnorms": true,
                "tokenizer": "raw"
            },
            "stored": true,
            "fast": false
            }
        },
        {
            "name": "title",
            "type": "text",
            "options": {
            "indexing": {
                "record": "position",
                "fieldnorms": true,
                "tokenizer": "unicode"
            },
            "stored": true,
            "fast": false
            }
        },
        {
            "name": "body",
            "type": "text",
            "options": {
            "indexing": {
                "record": "position",
                "fieldnorms": true,
                "tokenizer": "unicode"
            },
            "stored": true,
            "fast": false
            }
        }
        ]
        """
    }
}

@Suite(.serialized) struct TantivySwiftIndexTests {
    @Test func cleanup() throws {
        let fileManager = FileManager.default
        let indexPath = "./example_index"
        if fileManager.fileExists(atPath: indexPath) {
            try fileManager.removeItem(atPath: indexPath)
        }
    }

    @Test func createIndex() async throws {
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./example_index")
        let count = await index.count()
        assert(count == 0, "Index should be empty initially")
    }

    @Test func indexAndCountDocuments() async throws {
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./example_index")

        try await index.clear()
        var count = await index.count()
        assert(count == 0, "Index should be empty after clearing")

        let doc1 = ExampleIndexDoc(docId: "1", title: "First Document", body: "This is the body of the first document.")
        let doc2 = ExampleIndexDoc(docId: "2", title: "Second Document", body: "This is the body of the second document.")

        try await index.index(doc: doc1)
        try await index.index(doc: doc2)

        count = await index.count()
        assert(count == 2, "Index should contain 2 documents after indexing")
    }

    @Test func indexMultipleDocuments() async throws {
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./example_index")

        try await index.clear()
        var count = await index.count()
        assert(count == 0, "Index should be empty after clearing")

        let docs = [
            ExampleIndexDoc(docId: "3", title: "Third Document", body: "This is the body of the third document."),
            ExampleIndexDoc(docId: "4", title: "Fourth Document", body: "This is the body of the fourth document."),
            ExampleIndexDoc(docId: "5", title: "Fifth Document", body: "This is the body of the fifth document.")
        ]

        try await index.index(docs: docs)

        count = await index.count()
        assert(count == 3, "Index should contain 3 documents after indexing multiple documents")
    }

    @Test func retrieveDocument() async throws {
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./example_index")

        let docIdToRetrieve = "3"
        let doc = try await index.getDoc(idField: "docId", idValue: docIdToRetrieve)

        assert(doc != nil, "Document with docId \(docIdToRetrieve) should exist")
        assert(doc?.title == "Third Document", "Retrieved document title should match")
    }

    @Test func deleteDocument() async throws {
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./example_index")

        let docIdToDelete = "4"
        try await index.deleteDoc(idField: "docId", idValue: docIdToDelete)

        // we keep the error behavior and use try? to return nil if not found
        let doc = try? await index.getDoc(idField: "docId", idValue: docIdToDelete)

        assert(doc == nil, "Document with docId \(docIdToDelete) should have been deleted")

        let count = await index.count()

        assert(count == 2, "Index should contain 2 documents after deletion")
    }

    @Test func searchDocuments() async throws {
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./example_index")

        let query = TantivySearchQuery(
            queryStr: "fifth",
            defaultFields: [
                "title",
                "body"
            ],
            fuzzyFields: [
                TantivyFuzzyField(fieldName: "title", prefix: true, distance: 2, transposeCostOne: false),
                TantivyFuzzyField(fieldName: "body", prefix: true, distance: 2, transposeCostOne: false),
            ],
            topDocLimit: 10,
            lenient: true
        )
        let results = try await index.search(query: query)

        assert(results.count == 1, "Search should return 1 document")
        assert(results.docs.first?.doc.docId == "5", "Search result should be the document with docId 5")
    }
}
