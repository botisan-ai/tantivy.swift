import Foundation
import Testing
@testable import TantivySwift

@TantivyDocument
struct MacroTestDoc: TantivyIndexDocumentV2, Sendable {
    @IDField
    var id: String
    
    @TextField(tokenizer: .unicode, record: .withFreqsAndPositions, stored: true)
    var title: String
    
    @TextField(tokenizer: .unicode, stored: true)
    var body: String
    
    @DateField(indexed: true, stored: true, fast: true, precision: .seconds)
    var createdAt: Date
    
    @DoubleField(indexed: false, stored: true, fast: true)
    var score: Double
    
    @BoolField(stored: true)
    var isActive: Bool
    
    init(id: String = "", title: String = "", body: String = "", createdAt: Date = Date(), score: Double = 0.0, isActive: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.score = score
        self.isActive = isActive
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode([String].self, forKey: .id).first ?? ""
        title = try container.decode([String].self, forKey: .title).first ?? ""
        body = try container.decode([String].self, forKey: .body).first ?? ""
        let dateStr = try container.decode([String].self, forKey: .createdAt).first ?? ""
        createdAt = ISO8601DateFormatter().date(from: dateStr) ?? Date()
        score = try container.decode([Double].self, forKey: .score).first ?? 0.0
        isActive = try container.decode([Bool].self, forKey: .isActive).first ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(ISO8601DateFormatter().string(from: createdAt), forKey: .createdAt)
        try container.encode(score, forKey: .score)
        try container.encode(isActive, forKey: .isActive)
    }
}

struct ManualSchemaDoc: TantivyIndexDocumentV2, Sendable {
    enum CodingKeys: String, CodingKey {
        case docId, name
    }
    
    @IDField
    var docId: String
    
    @TextField(tokenizer: .unicode, stored: true)
    var name: String
    
    static var schemaTemplate: Self {
        ManualSchemaDoc(docId: "", name: "")
    }
    
    init(docId: String = "", name: String = "") {
        self.docId = docId
        self.name = name
    }
}

@Suite struct SchemaPropertyWrapperTests {
    
    @Test func textFieldDefaultOptions() {
        let field = TextField()
        #expect(field.wrappedValue == "")
        #expect(field.tokenizer == .unicode)
        #expect(field.record == .withFreqsAndPositions)
        #expect(field.stored == true)
        #expect(field.fast == false)
        #expect(field.fieldnorms == true)
        #expect(TextField.tantivyType == "text")
    }
    
    @Test func textFieldCustomOptions() {
        let field = TextField(wrappedValue: "test", tokenizer: .raw, record: .basic, stored: false, fast: true, fieldnorms: false)
        #expect(field.wrappedValue == "test")
        #expect(field.tokenizer == .raw)
        #expect(field.record == .basic)
        #expect(field.stored == false)
        #expect(field.fast == true)
        #expect(field.fieldnorms == false)
    }
    
    @Test func textFieldSchemaOptions() {
        let field = TextField(tokenizer: .enStem, record: .withFreqs, stored: true, fast: false, fieldnorms: true)
        let options = field.toSchemaOptions()
        
        #expect(options["stored"] as? Bool == true)
        #expect(options["fast"] as? Bool == false)
        
        let indexing = options["indexing"] as? [String: Any]
        #expect(indexing?["tokenizer"] as? String == "en_stem")
        #expect(indexing?["record"] as? String == "freq")
        #expect(indexing?["fieldnorms"] as? Bool == true)
    }
    
    @Test func idFieldDefaults() {
        let field = IDField()
        #expect(field.wrappedValue == "")
        #expect(field.stored == true)
        #expect(IDField.tantivyType == "text")
        
        let options = field.toSchemaOptions()
        let indexing = options["indexing"] as? [String: Any]
        #expect(indexing?["tokenizer"] as? String == "raw")
        #expect(indexing?["record"] as? String == "basic")
    }
    
    @Test func dateFieldOptions() {
        let field = DateField(indexed: true, stored: true, fast: true, precision: .milliseconds)
        #expect(DateField.tantivyType == "date")
        
        let options = field.toSchemaOptions()
        #expect(options["indexed"] as? Bool == true)
        #expect(options["stored"] as? Bool == true)
        #expect(options["fast"] as? Bool == true)
        #expect(options["precision"] as? String == "milliseconds")
    }
    
    @Test func doubleFieldOptions() {
        let field = DoubleField(wrappedValue: 3.14, indexed: false, stored: true, fast: true)
        #expect(field.wrappedValue == 3.14)
        #expect(DoubleField.tantivyType == "f64")
        
        let options = field.toSchemaOptions()
        #expect(options["indexed"] as? Bool == false)
        #expect(options["stored"] as? Bool == true)
        #expect(options["fast"] as? Bool == true)
    }
    
    @Test func boolFieldOptions() {
        let field = BoolField(wrappedValue: true, indexed: true, stored: true, fast: false)
        #expect(field.wrappedValue == true)
        #expect(BoolField.tantivyType == "bool")
        
        let options = field.toSchemaOptions()
        #expect(options["indexed"] as? Bool == true)
        #expect(options["stored"] as? Bool == true)
        #expect(options["fast"] as? Bool == false)
    }
    
    @Test func int64FieldOptions() {
        let field = Int64Field(wrappedValue: -42, indexed: true, stored: true, fast: true)
        #expect(field.wrappedValue == -42)
        #expect(Int64Field.tantivyType == "i64")
    }
    
    @Test func uint64FieldOptions() {
        let field = UInt64Field(wrappedValue: 42, indexed: true, stored: true, fast: true)
        #expect(field.wrappedValue == 42)
        #expect(UInt64Field.tantivyType == "u64")
    }
}

@Suite struct SchemaExtractorTests {
    
    @Test func manualSchemaTemplateGeneratesJSON() {
        let json = ManualSchemaDoc.schemaJsonStr()
        #expect(!json.isEmpty)
        #expect(json.contains("docId"))
        #expect(json.contains("name"))
        #expect(json.contains("text"))
    }
    
    @Test func schemaJSONContainsAllFields() throws {
        let json = MacroTestDoc.schemaJsonStr()
        let data = json.data(using: .utf8)!
        let fields = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        
        let fieldNames = fields.compactMap { $0["name"] as? String }
        #expect(fieldNames.contains("id"))
        #expect(fieldNames.contains("title"))
        #expect(fieldNames.contains("body"))
        #expect(fieldNames.contains("createdAt"))
        #expect(fieldNames.contains("score"))
        #expect(fieldNames.contains("isActive"))
    }
    
    @Test func schemaJSONHasCorrectTypes() throws {
        let json = MacroTestDoc.schemaJsonStr()
        let data = json.data(using: .utf8)!
        let fields = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        
        let fieldTypes = Dictionary(uniqueKeysWithValues: fields.map { 
            ($0["name"] as! String, $0["type"] as! String) 
        })
        
        #expect(fieldTypes["id"] == "text")
        #expect(fieldTypes["title"] == "text")
        #expect(fieldTypes["body"] == "text")
        #expect(fieldTypes["createdAt"] == "date")
        #expect(fieldTypes["score"] == "f64")
        #expect(fieldTypes["isActive"] == "bool")
    }
    
    @Test func schemaJSONHasCorrectOptions() throws {
        let json = MacroTestDoc.schemaJsonStr()
        let data = json.data(using: .utf8)!
        let fields = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        
        let scoreField = fields.first { $0["name"] as? String == "score" }!
        let options = scoreField["options"] as! [String: Any]
        #expect(options["fast"] as? Bool == true)
        #expect(options["stored"] as? Bool == true)
        #expect(options["indexed"] as? Bool == false)
    }
}

@Suite struct TantivyDocumentMacroTests {
    
    @Test func macroGeneratesCodingKeys() {
        let keys: [MacroTestDoc.CodingKeys] = [.id, .title, .body, .createdAt, .score, .isActive]
        #expect(keys.count == 6)
        #expect(MacroTestDoc.CodingKeys.id.stringValue == "id")
        #expect(MacroTestDoc.CodingKeys.title.stringValue == "title")
    }
    
    @Test func macroGeneratesSchemaTemplate() {
        let template = MacroTestDoc.schemaTemplate
        #expect(template.id == "")
        #expect(template.title == "")
        #expect(template.score == 0.0)
        #expect(template.isActive == false)
    }
    
    @Test func macroDocConformsToProtocol() {
        func checkConformance<T: TantivyIndexDocumentV2>(_ type: T.Type) -> Bool {
            return true
        }
        #expect(checkConformance(MacroTestDoc.self))
    }
}

@Suite struct TokenizerEnumTests {
    
    @Test func tokenizerRawValues() {
        #expect(Tokenizer.raw.rawValue == "raw")
        #expect(Tokenizer.unicode.rawValue == "unicode")
        #expect(Tokenizer.enStem.rawValue == "en_stem")
        #expect(Tokenizer.whitespace.rawValue == "whitespace")
        #expect(Tokenizer.default.rawValue == "default")
    }
}

@Suite struct IndexRecordOptionEnumTests {
    
    @Test func indexRecordRawValues() {
        #expect(IndexRecordOption.basic.rawValue == "basic")
        #expect(IndexRecordOption.withFreqs.rawValue == "freq")
        #expect(IndexRecordOption.withFreqsAndPositions.rawValue == "position")
    }
}

@Suite struct DatePrecisionEnumTests {
    
    @Test func datePrecisionRawValues() {
        #expect(DatePrecision.seconds.rawValue == "seconds")
        #expect(DatePrecision.milliseconds.rawValue == "milliseconds")
        #expect(DatePrecision.microseconds.rawValue == "microseconds")
    }
}
