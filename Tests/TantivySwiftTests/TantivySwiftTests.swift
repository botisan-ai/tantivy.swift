import Foundation
import Testing
@testable import TantivySwift
import TantivyFFI

struct ReceiptIndexItem: Codable, TantivyIndexDocument {
    enum CodingKeys: String, CodingKey {
        case receiptId
        case merchantName
        case transactionDate
        case convertedTotal
        case notes
        case tags
    }

    var receiptId: String
    var merchantName: String
    var transactionDate: Date
    var convertedTotal: Double
    var notes: String?
    var tags: [String]

    init(receiptId: String, merchantName: String, transactionDate: Date, convertedTotal: Double, notes: String? = nil, tags: [String]? = nil) {
        self.receiptId = receiptId
        self.merchantName = merchantName
        self.transactionDate = transactionDate
        self.convertedTotal = convertedTotal
        self.notes = notes
        self.tags = tags ?? []
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let receiptIdField = try container.decode([String].self, forKey: .receiptId)

        guard let receiptId = receiptIdField.first else {
            throw DecodingError.dataCorruptedError(forKey: .receiptId, in: container, debugDescription: "receiptId field is empty")
        }

        self.receiptId = receiptId

        merchantName = try container.decode([String].self, forKey: .merchantName).first ?? ""

        let transactionDateField = try container.decode([String].self, forKey: .transactionDate)

        guard let transactionDateStr = transactionDateField.first else {
            throw DecodingError.dataCorruptedError(forKey: .transactionDate, in: container, debugDescription: "transactionDate field is empty")
        }

        let dateFormatter = ISO8601DateFormatter()

        guard let transactionDate = dateFormatter.date(from: transactionDateStr) else {
            throw DecodingError.dataCorruptedError(forKey: .transactionDate, in: container, debugDescription: "Invalid date format for transactionDate")
        }

        self.transactionDate = transactionDate

        convertedTotal = try container.decode([Double].self, forKey: .convertedTotal).first ?? 0.0

        notes = try container.decodeIfPresent([String].self, forKey: .notes)?.first

        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(receiptId, forKey: .receiptId)
        try container.encode(merchantName, forKey: .merchantName)

        // encode date as ISO8601 string
        let dateFormatter = ISO8601DateFormatter()
        try container.encode(dateFormatter.string(from: transactionDate), forKey: .transactionDate)

        try container.encode(convertedTotal, forKey: .convertedTotal)

        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(tags, forKey: .tags)
    }

    static func schemaJsonStr() -> String {
        return """
        [
          {
            "name": "receiptId",
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
            "name": "merchantName",
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
            "name": "transactionDate",
            "type": "date",
            "options": {
              "indexed": true,
              "fieldnorms": true,
              "fast": false,
              "stored": true,
              "precision": "seconds"
            }
          },
          {
            "name": "convertedTotal",
            "type": "f64",
            "options": {
              "indexed": false,
              "fieldnorms": false,
              "fast": true,
              "stored": true
            }
          },
          {
            "name": "notes",
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
            "name": "tags",
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
          }
        ]
        """
    }
}

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
        let indexPath = "./test_data/example_index"
        if fileManager.fileExists(atPath: indexPath) {
            try fileManager.removeItem(atPath: indexPath)
        }
    }

    @Test func createIndex() async throws {
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./test_data/example_index")
        let count = await index.count()
        assert(count == 0, "Index should be empty initially")
    }

    @Test func indexAndCountDocuments() async throws {
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./test_data/example_index")

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
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./test_data/example_index")

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
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./test_data/example_index")

        let docIdToRetrieve = "3"
        let doc = try await index.getDoc(idField: .docId, idValue: docIdToRetrieve)

        assert(doc != nil, "Document with docId \(docIdToRetrieve) should exist")
        assert(doc?.title == "Third Document", "Retrieved document title should match")
    }

    @Test func deleteDocument() async throws {
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./test_data/example_index")

        let docIdToDelete = "4"
        try await index.deleteDoc(idField: .docId, idValue: docIdToDelete)

        // we keep the error behavior and use try? to return nil if not found
        let doc = try? await index.getDoc(idField: .docId, idValue: docIdToDelete)

        assert(doc == nil, "Document with docId \(docIdToDelete) should have been deleted")

        let count = await index.count()

        assert(count == 2, "Index should contain 2 documents after deletion")
    }

    @Test func searchDocuments() async throws {
        let index = try TantivySwiftIndex<ExampleIndexDoc>(path: "./test_data/example_index")

        let query = TantivySwiftSearchQuery<ExampleIndexDoc>(
            queryStr: "fifth",
            defaultFields: [.title, .body],
            fuzzyFields: [
                TantivySwiftFuzzyField(field: .title, prefix: true, distance: 2, transposeCostOne: false),
                TantivySwiftFuzzyField(field: .body, prefix: true, distance: 2, transposeCostOne: false),
            ]
        )
        let results = try await index.search(query: query)

        assert(results.count == 1, "Search should return 1 document")
        assert(results.docs.first?.doc.docId == "5", "Search result should be the document with docId 5")
    }

    @Test func complexIndex() async throws {
        let index = try TantivySwiftIndex<ReceiptIndexItem>(path: "./test_data/receipt_index")

        try await index.clear()
        var count = await index.count()
        assert(count == 0, "Index should be empty after clearing")

        // there are optional fields here, so it is a test for serialization/deserialization as well
        let receipt = ReceiptIndexItem(
            receiptId: "r1",
            merchantName: "Starbucks Coffee",
            transactionDate: Date(),
            convertedTotal: 4.50
        )

        try await index.index(doc: receipt)

        count = await index.count()
        assert(count == 1, "Index should contain 1 document after indexing a receipt")

        let doc = try await index.getDoc(idField: .receiptId, idValue: "r1")
        assert(doc != nil, "Document with receiptId r1 should exist")
        assert(doc?.merchantName == "Starbucks Coffee", "Retrieved document merchantName should match")

        let query = TantivySwiftSearchQuery<ReceiptIndexItem>(
            queryStr: "coffee",
            defaultFields: [.merchantName, .notes, .tags],
            fuzzyFields: [
                .init(field: .merchantName, prefix: true, distance: 2),
                .init(field: .notes, prefix: true, distance: 2),
            ],
            limit: 20,
            offset: 0
        )

        let results = try await index.search(query: query)

        assert(results.count == 1, "Search should return 1 document")
        assert(results.docs.first?.doc.receiptId == "r1", "Search result should be the document with receiptId r1")
    }
}
