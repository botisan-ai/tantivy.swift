import Foundation
import Testing
@testable import TantivySwift
import TantivyFFI

@TantivyDocument
struct SimpleMacroDoc: Sendable {
    @IDField var id: String
    @TextField var title: String
    @TextField var body: String
    @F64Field var score: Double
    @BoolField var isActive: Bool

    init(id: String, title: String, body: String, score: Double, isActive: Bool) {
        self.id = id
        self.title = title
        self.body = body
        self.score = score
        self.isActive = isActive
    }
}

struct NativeSchemaDoc: TantivyDocument, Sendable {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case score
        case isActive
    }

    @IDField var id: String
    @TextField var title: String
    @TextField var body: String
    @F64Field var score: Double
    @BoolField var isActive: Bool

    init(id: String, title: String, body: String, score: Double, isActive: Bool) {
        self.id = id
        self.title = title
        self.body = body
        self.score = score
        self.isActive = isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = IDField(wrappedValue: try container.decode([String].self, forKey: .id).first ?? "")
        _title = TextField(wrappedValue: try container.decode([String].self, forKey: .title).first ?? "")
        _body = TextField(wrappedValue: try container.decode([String].self, forKey: .body).first ?? "")
        _score = F64Field(wrappedValue: try container.decode([Double].self, forKey: .score).first ?? 0.0)
        _isActive = BoolField(wrappedValue: try container.decode([Bool].self, forKey: .isActive).first ?? false)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(score, forKey: .score)
        try container.encode(isActive, forKey: .isActive)
    }

    static func schemaTemplate() -> NativeSchemaDoc {
        return NativeSchemaDoc(id: "", title: "", body: "", score: 0.0, isActive: false)
    }
}

@Suite(.serialized) struct NativeSchemaTests {
    
    @Test func schemaExtractorBuildsCorrectSchema() throws {
        let builder = TantivySchemaExtractor.buildSchema(for: NativeSchemaDoc.self)
        #expect(builder != nil)
    }
    
    @Test func createNativeIndex() async throws {
        let fileManager = FileManager.default
        let indexPath = "./test_data/native_schema_index"
        if fileManager.fileExists(atPath: indexPath) {
            try fileManager.removeItem(atPath: indexPath)
        }
        
        let index = try TantivySwiftNativeIndex<NativeSchemaDoc>(path: indexPath)
        let count = await index.count()
        #expect(count == 0)
    }
    
    @Test func indexAndRetrieveWithNativeSchema() async throws {
        let indexPath = "./test_data/native_schema_index"
        let index = try TantivySwiftNativeIndex<NativeSchemaDoc>(path: indexPath)
        
        try await index.clear()
        
        let doc = NativeSchemaDoc(
            id: "doc1",
            title: "Test Document",
            body: "This is a test document body.",
            score: 95.5,
            isActive: true
        )
        
        try await index.index(doc: doc)
        
        let count = await index.count()
        #expect(count == 1)
        
        let retrieved = try await index.getDoc(idField: .id, idValue: "doc1")
        #expect(retrieved != nil)
        #expect(retrieved?.title == "Test Document")
        #expect(retrieved?.score == 95.5)
        #expect(retrieved?.isActive == true)
    }
    
    @Test func indexMultipleDocsWithNativeSchema() async throws {
        let indexPath = "./test_data/native_schema_index"
        let index = try TantivySwiftNativeIndex<NativeSchemaDoc>(path: indexPath)
        
        try await index.clear()
        
        let docs = [
            NativeSchemaDoc(id: "a1", title: "Alpha", body: "First letter", score: 1.0, isActive: true),
            NativeSchemaDoc(id: "b2", title: "Beta", body: "Second letter", score: 2.0, isActive: false),
            NativeSchemaDoc(id: "c3", title: "Charlie", body: "Third letter", score: 3.0, isActive: true),
        ]
        
        try await index.index(docs: docs)
        
        let count = await index.count()
        #expect(count == 3)
    }
    
    @Test func deleteDocWithNativeSchema() async throws {
        let indexPath = "./test_data/native_schema_index"
        let index = try TantivySwiftNativeIndex<NativeSchemaDoc>(path: indexPath)
        
        try await index.deleteDoc(idField: .id, idValue: "b2")
        
        let exists = try await index.docExists(idField: .id, idValue: "b2")
        #expect(exists == false)
        
        let count = await index.count()
        #expect(count == 2)
    }
}

@Suite(.serialized) struct MacroTests {
    
    @Test func macroGeneratesSchemaTemplate() throws {
        let template = SimpleMacroDoc.schemaTemplate()
        #expect(template.id == "")
        #expect(template.title == "")
        #expect(template.body == "")
        #expect(template.score == 0.0)
        #expect(template.isActive == false)
    }
    
    @Test func macroDocConformsToTantivyDocument() throws {
        let builder = TantivySchemaExtractor.buildSchema(for: SimpleMacroDoc.self)
        #expect(builder != nil)
    }
    
    @Test func macroDocWorksWithIndex() async throws {
        let fileManager = FileManager.default
        let indexPath = "./test_data/macro_test_index"
        if fileManager.fileExists(atPath: indexPath) {
            try fileManager.removeItem(atPath: indexPath)
        }
        
        let index = try TantivySwiftNativeIndex<SimpleMacroDoc>(path: indexPath)
        
        let doc = SimpleMacroDoc(
            id: "macro1",
            title: "Macro Generated",
            body: "This doc uses macro-generated everything",
            score: 100.0,
            isActive: true
        )
        
        try await index.index(doc: doc)
        
        let count = await index.count()
        #expect(count == 1)
        
        let retrieved = try await index.getDoc(idField: .id, idValue: "macro1")
        #expect(retrieved != nil)
        #expect(retrieved?.title == "Macro Generated")
        #expect(retrieved?.score == 100.0)
        #expect(retrieved?.isActive == true)
    }
    
    @Test func macroGeneratesCodingKeys() throws {
        let doc = SimpleMacroDoc(id: "test", title: "Test", body: "Body", score: 1.0, isActive: true)
        let encoder = JSONEncoder()
        let data = try encoder.encode(doc)
        let json = String(data: data, encoding: .utf8)!
        
        #expect(json.contains("\"id\""))
        #expect(json.contains("\"title\""))
        #expect(json.contains("\"body\""))
        #expect(json.contains("\"score\""))
        #expect(json.contains("\"isActive\""))
    }
}
