import Foundation
import Testing
@testable import TantivySwift
import TantivyFFI

struct ArticleMeta: Codable, Sendable {
    var source: String = ""
    var rating: Int = 0
}

@TantivyDocument
struct UnifiedDoc: Sendable {
    @IDField var id: String
    @TextField var title: String
    @TextField var body: String
    @F64Field var score: Double
    @BoolField var isActive: Bool
    @FacetField var category: String
    @JsonField var meta: ArticleMeta

    init(id: String, title: String, body: String, score: Double, isActive: Bool, category: String, meta: ArticleMeta) {
        self.id = id
        self.title = title
        self.body = body
        self.score = score
        self.isActive = isActive
        self.category = category
        self.meta = meta
    }
}

private func makeIndex(_ name: String) throws -> TantivySwiftIndex<UnifiedDoc> {
    let indexPath = "./test_data/\(name)"
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: indexPath) {
        try fileManager.removeItem(atPath: indexPath)
    }
    return try TantivySwiftIndex<UnifiedDoc>(path: indexPath)
}

@Suite(.serialized) struct TantivySwiftTests {

    @Test func schemaTemplateAndCodingKeys() throws {
        let template = UnifiedDoc.schemaTemplate()
        #expect(template.id == "")
        #expect(template.title == "")
        #expect(template.body == "")
        #expect(template.score == 0.0)
        #expect(template.isActive == false)
        #expect(template.category == "")
        #expect(template.meta.source == "")

        let doc = UnifiedDoc(
            id: "sample",
            title: "Title",
            body: "Body",
            score: 1.0,
            isActive: true,
            category: "/sample",
            meta: ArticleMeta(source: "swift", rating: 1)
        )
        let data = try JSONEncoder().encode(doc)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\"id\""))
        #expect(json.contains("\"title\""))
        #expect(json.contains("\"body\""))
        #expect(json.contains("\"category\""))
        #expect(json.contains("\"meta\""))
    }

    @Test func indexLifecycle() async throws {
        let index = try makeIndex("unified_index_lifecycle")
        try await index.clear()

        let doc = UnifiedDoc(
            id: "1",
            title: "Swift and Rust",
            body: "Exploring search indexes",
            score: 9.5,
            isActive: true,
            category: "/tech",
            meta: ArticleMeta(source: "swift", rating: 5)
        )

        try await index.add(doc: doc)
        try await index.commit()

        let count = await index.count()
        #expect(count == 1)

        let idField = DocumentField(field: UnifiedDoc.CodingKeys.id, value: .text("1"))
        let exists = try await index.docExists(id: idField)
        #expect(exists == true)

        let retrieved = try await index.getDoc(id: idField)
        #expect(retrieved?.title == "Swift and Rust")

        try await index.deleteDoc(id: idField)
        let existsAfter = try await index.docExists(id: idField)
        #expect(existsAfter == false)
        #expect(await index.count() == 0)
    }

    @Test func bulkIndexAndGetDocs() async throws {
        let index = try makeIndex("unified_index_bulk")
        try await index.clear()

        let docs = [
            UnifiedDoc(id: "a1", title: "Alpha", body: "First letter", score: 1.0, isActive: true, category: "/letters", meta: ArticleMeta(source: "alpha", rating: 1)),
            UnifiedDoc(id: "b2", title: "Beta", body: "Second letter", score: 2.0, isActive: false, category: "/letters", meta: ArticleMeta(source: "beta", rating: 2)),
            UnifiedDoc(id: "c3", title: "Charlie", body: "Third letter", score: 3.0, isActive: true, category: "/letters", meta: ArticleMeta(source: "charlie", rating: 3)),
        ]

        try await index.add(docs: docs)
        try await index.commit()
        #expect(await index.count() == 3)

        let extra = UnifiedDoc(id: "d4", title: "Delta", body: "Fourth letter", score: 4.0, isActive: true, category: "/letters", meta: ArticleMeta(source: "delta", rating: 4))
        try await index.index(doc: extra)
        #expect(await index.count() == 4)

        let more = UnifiedDoc(id: "e5", title: "Echo", body: "Fifth letter", score: 5.0, isActive: false, category: "/letters", meta: ArticleMeta(source: "echo", rating: 5))
        try await index.index(docs: [more])
        #expect(await index.count() == 5)

        let retrieved = try await index.getDocs(ids: [
            DocumentField(field: UnifiedDoc.CodingKeys.id, value: .text("a1")),
            DocumentField(field: UnifiedDoc.CodingKeys.id, value: .text("b2")),
        ])
        #expect(retrieved.count == 2)
    }

    @Test func searchQueries() async throws {
        let index = try makeIndex("unified_index_search")
        try await index.clear()

        let doc1 = UnifiedDoc(
            id: "1",
            title: "Swift and Rust",
            body: "Exploring search indexes",
            score: 10.0,
            isActive: true,
            category: "/tech",
            meta: ArticleMeta(source: "swift", rating: 5)
        )
        let doc2 = UnifiedDoc(
            id: "2",
            title: "Cooking Pasta",
            body: "Simple recipes",
            score: 6.0,
            isActive: false,
            category: "/food",
            meta: ArticleMeta(source: "kitchen", rating: 4)
        )

        try await index.index(docs: [doc1, doc2])

        let textQuery = TantivyQuery.queryString(
            TantivyQueryString(
                query: "swift",
                defaultFields: ["title", "body"]
            )
        )
        let facetQuery = TantivyQuery.term(
            TantivyQueryTerm(name: "category", value: .facet("/tech"))
        )
        let combined = TantivyQuery.boolean([
            TantivyBooleanClause(occur: .must, query: textQuery),
            TantivyBooleanClause(occur: .must, query: facetQuery),
        ])

        let results = try await index.search(query: combined, limit: 10, offset: 0)
        #expect(results.count == 1)
        #expect(results.docs.first?.doc.id == "1")

        let query = TantivySwiftSearchQuery<UnifiedDoc>(
            queryStr: "pasta",
            defaultFields: [.title, .body]
        )

        let results2 = try await index.search(query: query)
        #expect(results2.count == 1)
        #expect(results2.docs.first?.doc.id == "2")
    }
}
