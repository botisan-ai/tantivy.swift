import Foundation
import Testing
@testable import TantivySwift
import TantivyFFI

struct ArticleMeta: Codable, Sendable, Equatable {
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

@TantivyDocument
struct MultiValueDoc: Sendable {
    @IDField var id: String
    @TextField(tokenizer: .raw, record: .basic, stored: true, fast: false, fieldnorms: true)
    var tags: [String] = []
    @FacetField(stored: true)
    var receiptTagIds: [String] = []
    @TextField var note: String

    init(id: String, tags: [String], receiptTagIds: [String], note: String) {
        self.id = id
        self.tags = tags
        self.receiptTagIds = receiptTagIds
        self.note = note
    }
}

@TantivyDocument
struct MultiValueAllDoc: Sendable {
    @IDField var id: String
    @TextField(tokenizer: .raw, record: .basic, stored: true, fast: false, fieldnorms: true)
    var tags: [String] = []
    @U64Field(indexed: true, stored: true, fast: true, fieldnorms: false)
    var amounts: [UInt64] = []
    @I64Field(indexed: true, stored: true, fast: true, fieldnorms: false)
    var deltas: [Int64] = []
    @F64Field(indexed: true, stored: true, fast: true, fieldnorms: false)
    var scores: [Double] = []
    @BoolField(indexed: true, stored: true, fast: true, fieldnorms: false)
    var flags: [Bool] = []
    @DateField(indexed: true, stored: true, fast: true, fieldnorms: false, precision: .microseconds)
    var times: [Date] = []
    @BytesField(stored: true, fast: false, indexed: true)
    var blobs: [Data] = []
    @FacetField(stored: true)
    var receiptTagIds: [String] = []
    @JsonField(stored: true, indexed: false, fast: false)
    var metas: [ArticleMeta] = []

    init(
        id: String,
        tags: [String],
        amounts: [UInt64],
        deltas: [Int64],
        scores: [Double],
        flags: [Bool],
        times: [Date],
        blobs: [Data],
        receiptTagIds: [String],
        metas: [ArticleMeta]
    ) {
        self.id = id
        self.tags = tags
        self.amounts = amounts
        self.deltas = deltas
        self.scores = scores
        self.flags = flags
        self.times = times
        self.blobs = blobs
        self.receiptTagIds = receiptTagIds
        self.metas = metas
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

private func makeMultiValueIndex(_ name: String) throws -> TantivySwiftIndex<MultiValueDoc> {
    let indexPath = "./test_data/\(name)"
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: indexPath) {
        try fileManager.removeItem(atPath: indexPath)
    }
    return try TantivySwiftIndex<MultiValueDoc>(path: indexPath)
}

private func makeMultiValueAllIndex(_ name: String) throws -> TantivySwiftIndex<MultiValueAllDoc> {
    let indexPath = "./test_data/\(name)"
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: indexPath) {
        try fileManager.removeItem(atPath: indexPath)
    }
    return try TantivySwiftIndex<MultiValueAllDoc>(path: indexPath)
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

    @Test func multiValueTextAndFacetFields() async throws {
        let doc = MultiValueDoc(
            id: "receipt-1",
            tags: ["groceries", "weekly"],
            receiptTagIds: ["/receipt/tags/groceries", "/receipt/tags/home"],
            note: "Weekly grocery run"
        )

        let native = try doc.toTantivyDocument()
        #expect(native.fields.filter { $0.name == "tags" }.count == 2)
        #expect(native.fields.filter { $0.name == "receiptTagIds" }.count == 2)

        let mapped = TantivyDocumentFieldMap(native)
        #expect(Set(mapped.texts("tags")) == Set(doc.tags))
        #expect(Set(mapped.facets("receiptTagIds")) == Set(doc.receiptTagIds))

        let rebuilt = try MultiValueDoc(fromFields: native)
        #expect(Set(rebuilt.tags) == Set(doc.tags))
        #expect(Set(rebuilt.receiptTagIds) == Set(doc.receiptTagIds))

        let index = try makeMultiValueIndex("multivalue_text_facet")
        try await index.clear()
        try await index.index(doc: doc)

        let idField = DocumentField(field: MultiValueDoc.CodingKeys.id, value: .text("receipt-1"))
        let retrieved = try await index.getDoc(id: idField)
        #expect(retrieved?.id == "receipt-1")
        #expect(Set(retrieved?.tags ?? []) == Set(doc.tags))
        #expect(Set(retrieved?.receiptTagIds ?? []) == Set(doc.receiptTagIds))

        let tagsQuery = TantivyQuery.term(
            TantivyQueryTerm(name: "tags", value: .text("weekly"))
        )
        let tagsResults = try await index.search(query: tagsQuery, limit: 10, offset: 0)
        #expect(tagsResults.count == 1)
        #expect(tagsResults.docs.first?.doc.id == "receipt-1")

        let facetQuery = TantivyQuery.term(
            TantivyQueryTerm(name: "receiptTagIds", value: .facet("/receipt/tags/home"))
        )
        let facetResults = try await index.search(query: facetQuery, limit: 10, offset: 0)
        #expect(facetResults.count == 1)
        #expect(facetResults.docs.first?.doc.id == "receipt-1")
    }

    @Test func multiValueAllSupportedFieldTypes() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000.123456)
        let later = Date(timeIntervalSince1970: 1_700_000_100.654321)

        let doc = MultiValueAllDoc(
            id: "multi-1",
            tags: ["groceries", "household"],
            amounts: [12, 42],
            deltas: [-4, 7],
            scores: [0.75, 0.95],
            flags: [true, false],
            times: [now, later],
            blobs: [Data([0xCA, 0xFE]), Data([0xBA, 0xBE])],
            receiptTagIds: ["/receipt/tags/groceries", "/receipt/tags/home"],
            metas: [ArticleMeta(source: "ocr", rating: 5), ArticleMeta(source: "manual", rating: 4)]
        )

        let native = try doc.toTantivyDocument()
        #expect(native.fields.filter { $0.name == "tags" }.count == doc.tags.count)
        #expect(native.fields.filter { $0.name == "amounts" }.count == doc.amounts.count)
        #expect(native.fields.filter { $0.name == "deltas" }.count == doc.deltas.count)
        #expect(native.fields.filter { $0.name == "scores" }.count == doc.scores.count)
        #expect(native.fields.filter { $0.name == "flags" }.count == doc.flags.count)
        #expect(native.fields.filter { $0.name == "times" }.count == doc.times.count)
        #expect(native.fields.filter { $0.name == "blobs" }.count == doc.blobs.count)
        #expect(native.fields.filter { $0.name == "receiptTagIds" }.count == doc.receiptTagIds.count)
        #expect(native.fields.filter { $0.name == "metas" }.count == doc.metas.count)

        let mapped = TantivyDocumentFieldMap(native)
        #expect(Set(mapped.texts("tags")) == Set(doc.tags))
        #expect(mapped.u64s("amounts") == doc.amounts)
        #expect(mapped.i64s("deltas") == doc.deltas)
        #expect(mapped.f64s("scores") == doc.scores)
        #expect(mapped.bools("flags") == doc.flags)
        #expect(mapped.bytesValues("blobs") == doc.blobs)
        #expect(Set(mapped.facets("receiptTagIds")) == Set(doc.receiptTagIds))

        let mappedTimesMicros = mapped.dates("times").map { Int64(($0.timeIntervalSince1970 * 1_000_000).rounded()) }
        let originalTimesMicros = doc.times.map { Int64(($0.timeIntervalSince1970 * 1_000_000).rounded()) }
        #expect(mappedTimesMicros == originalTimesMicros)

        let mappedMetas = try mapped.jsons("metas").map { try TantivyJsonCoding.decode(ArticleMeta.self, from: $0) }
        #expect(mappedMetas == doc.metas)

        let rebuilt = try MultiValueAllDoc(fromFields: native)
        #expect(Set(rebuilt.tags) == Set(doc.tags))
        #expect(rebuilt.amounts == doc.amounts)
        #expect(rebuilt.deltas == doc.deltas)
        #expect(rebuilt.scores == doc.scores)
        #expect(rebuilt.flags == doc.flags)
        #expect(rebuilt.blobs == doc.blobs)
        #expect(Set(rebuilt.receiptTagIds) == Set(doc.receiptTagIds))
        #expect(rebuilt.metas == doc.metas)

        let rebuiltTimesMicros = rebuilt.times.map { Int64(($0.timeIntervalSince1970 * 1_000_000).rounded()) }
        #expect(rebuiltTimesMicros == originalTimesMicros)

        let index = try makeMultiValueAllIndex("multivalue_all_fields")
        try await index.clear()
        try await index.index(doc: doc)

        let idField = DocumentField(field: MultiValueAllDoc.CodingKeys.id, value: .text(doc.id))
        let retrieved = try await index.getDoc(id: idField)
        #expect(retrieved != nil)
        #expect(retrieved?.id == doc.id)
        #expect(retrieved?.amounts == doc.amounts)
        #expect(retrieved?.deltas == doc.deltas)
        #expect(retrieved?.scores == doc.scores)
        #expect(retrieved?.flags == doc.flags)
        #expect(retrieved?.blobs == doc.blobs)
        #expect(retrieved?.metas == doc.metas)

        let textResults = try await index.search(
            query: TantivyQuery.term(TantivyQueryTerm(name: "tags", value: .text("groceries"))),
            limit: 10,
            offset: 0
        )
        #expect(textResults.count == 1)

        let u64Results = try await index.search(
            query: TantivyQuery.term(TantivyQueryTerm(name: "amounts", value: .u64(42))),
            limit: 10,
            offset: 0
        )
        #expect(u64Results.count == 1)

        let i64Results = try await index.search(
            query: TantivyQuery.term(TantivyQueryTerm(name: "deltas", value: .i64(-4))),
            limit: 10,
            offset: 0
        )
        #expect(i64Results.count == 1)

        let f64Results = try await index.search(
            query: TantivyQuery.term(TantivyQueryTerm(name: "scores", value: .f64(0.95))),
            limit: 10,
            offset: 0
        )
        #expect(f64Results.count == 1)

        let boolResults = try await index.search(
            query: TantivyQuery.term(TantivyQueryTerm(name: "flags", value: .bool(true))),
            limit: 10,
            offset: 0
        )
        #expect(boolResults.count == 1)

        let bytesResults = try await index.search(
            query: TantivyQuery.term(TantivyQueryTerm(name: "blobs", value: .bytes(Data([0xCA, 0xFE])))),
            limit: 10,
            offset: 0
        )
        #expect(bytesResults.count == 1)

        let facetResults = try await index.search(
            query: TantivyQuery.term(TantivyQueryTerm(name: "receiptTagIds", value: .facet("/receipt/tags/home"))),
            limit: 10,
            offset: 0
        )
        #expect(facetResults.count == 1)
    }
}
