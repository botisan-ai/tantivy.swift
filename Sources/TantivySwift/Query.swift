import Foundation

public indirect enum TantivyQuery: Codable, Sendable {
    case all
    case empty
    case term(TantivyQueryTerm)
    case termSet([TantivyQueryTerm])
    case boolean([TantivyBooleanClause])
    case phrase(field: String, terms: [String], slop: UInt32?)
    case phrasePrefix(field: String, terms: [String], maxExpansions: UInt32?)
    case range(field: String, lower: TantivyQueryValue?, upper: TantivyQueryValue?, includeLower: Bool, includeUpper: Bool)
    case regex(field: String, pattern: String)
    case fuzzy(field: String, term: String, distance: UInt8, transposeCostOne: Bool)
    case exists(field: String)
    case boost(query: TantivyQuery, boost: Float)
    case constScore(query: TantivyQuery, score: Float)
    case disjunctionMax(queries: [TantivyQuery], tieBreaker: Float?)
    case queryString(TantivyQueryString)

    public func toJson() throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(codingPath: [], debugDescription: "Invalid UTF-8 data")
            )
        }
        return json
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case term
        case terms
        case clauses
        case field
        case lower
        case upper
        case includeLower = "include_lower"
        case includeUpper = "include_upper"
        case pattern
        case distance
        case transposeCostOne = "transpose_cost_one"
        case maxExpansions = "max_expansions"
        case slop
        case tieBreaker = "tie_breaker"
        case query
        case queries
        case boost
        case score
        case defaultFields = "default_fields"
        case fuzzyFields = "fuzzy_fields"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .all:
            try container.encode("all", forKey: .type)

        case .empty:
            try container.encode("empty", forKey: .type)

        case .term(let term):
            try container.encode("term", forKey: .type)
            try container.encode(term, forKey: .term)

        case .termSet(let terms):
            try container.encode("term_set", forKey: .type)
            try container.encode(terms, forKey: .terms)

        case .boolean(let clauses):
            try container.encode("boolean", forKey: .type)
            try container.encode(clauses, forKey: .clauses)

        case .phrase(let field, let terms, let slop):
            try container.encode("phrase", forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encode(terms, forKey: .terms)
            try container.encodeIfPresent(slop, forKey: .slop)

        case .phrasePrefix(let field, let terms, let maxExpansions):
            try container.encode("phrase_prefix", forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encode(terms, forKey: .terms)
            try container.encodeIfPresent(maxExpansions, forKey: .maxExpansions)

        case .range(let field, let lower, let upper, let includeLower, let includeUpper):
            try container.encode("range", forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encodeIfPresent(lower, forKey: .lower)
            try container.encodeIfPresent(upper, forKey: .upper)
            try container.encode(includeLower, forKey: .includeLower)
            try container.encode(includeUpper, forKey: .includeUpper)

        case .regex(let field, let pattern):
            try container.encode("regex", forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encode(pattern, forKey: .pattern)

        case .fuzzy(let field, let term, let distance, let transposeCostOne):
            try container.encode("fuzzy", forKey: .type)
            try container.encode(field, forKey: .field)
            try container.encode(term, forKey: .term)
            try container.encode(distance, forKey: .distance)
            try container.encode(transposeCostOne, forKey: .transposeCostOne)

        case .exists(let field):
            try container.encode("exists", forKey: .type)
            try container.encode(field, forKey: .field)

        case .boost(let query, let boost):
            try container.encode("boost", forKey: .type)
            try container.encode(query, forKey: .query)
            try container.encode(boost, forKey: .boost)

        case .constScore(let query, let score):
            try container.encode("const_score", forKey: .type)
            try container.encode(query, forKey: .query)
            try container.encode(score, forKey: .score)

        case .disjunctionMax(let queries, let tieBreaker):
            try container.encode("disjunction_max", forKey: .type)
            try container.encode(queries, forKey: .queries)
            try container.encodeIfPresent(tieBreaker, forKey: .tieBreaker)

        case .queryString(let queryString):
            try container.encode("query_string", forKey: .type)
            try container.encode(queryString.query, forKey: .query)
            try container.encode(queryString.defaultFields, forKey: .defaultFields)
            try container.encode(queryString.fuzzyFields, forKey: .fuzzyFields)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "all":
            self = .all
        case "empty":
            self = .empty
        case "term":
            self = .term(try container.decode(TantivyQueryTerm.self, forKey: .term))
        case "term_set":
            self = .termSet(try container.decode([TantivyQueryTerm].self, forKey: .terms))
        case "boolean":
            self = .boolean(try container.decode([TantivyBooleanClause].self, forKey: .clauses))
        case "phrase":
            let field = try container.decode(String.self, forKey: .field)
            let terms = try container.decode([String].self, forKey: .terms)
            let slop = try container.decodeIfPresent(UInt32.self, forKey: .slop)
            self = .phrase(field: field, terms: terms, slop: slop)
        case "phrase_prefix":
            let field = try container.decode(String.self, forKey: .field)
            let terms = try container.decode([String].self, forKey: .terms)
            let maxExpansions = try container.decodeIfPresent(UInt32.self, forKey: .maxExpansions)
            self = .phrasePrefix(field: field, terms: terms, maxExpansions: maxExpansions)
        case "range":
            let field = try container.decode(String.self, forKey: .field)
            let lower = try container.decodeIfPresent(TantivyQueryValue.self, forKey: .lower)
            let upper = try container.decodeIfPresent(TantivyQueryValue.self, forKey: .upper)
            let includeLower = try container.decode(Bool.self, forKey: .includeLower)
            let includeUpper = try container.decode(Bool.self, forKey: .includeUpper)
            self = .range(field: field, lower: lower, upper: upper, includeLower: includeLower, includeUpper: includeUpper)
        case "regex":
            let field = try container.decode(String.self, forKey: .field)
            let pattern = try container.decode(String.self, forKey: .pattern)
            self = .regex(field: field, pattern: pattern)
        case "fuzzy":
            let field = try container.decode(String.self, forKey: .field)
            let term = try container.decode(String.self, forKey: .term)
            let distance = try container.decode(UInt8.self, forKey: .distance)
            let transposeCostOne = try container.decode(Bool.self, forKey: .transposeCostOne)
            self = .fuzzy(field: field, term: term, distance: distance, transposeCostOne: transposeCostOne)
        case "exists":
            let field = try container.decode(String.self, forKey: .field)
            self = .exists(field: field)
        case "boost":
            let query = try container.decode(TantivyQuery.self, forKey: .query)
            let boost = try container.decode(Float.self, forKey: .boost)
            self = .boost(query: query, boost: boost)
        case "const_score":
            let query = try container.decode(TantivyQuery.self, forKey: .query)
            let score = try container.decode(Float.self, forKey: .score)
            self = .constScore(query: query, score: score)
        case "disjunction_max":
            let queries = try container.decode([TantivyQuery].self, forKey: .queries)
            let tieBreaker = try container.decodeIfPresent(Float.self, forKey: .tieBreaker)
            self = .disjunctionMax(queries: queries, tieBreaker: tieBreaker)
        case "query_string":
            let query = try container.decode(String.self, forKey: .query)
            let defaultFields = try container.decodeIfPresent([String].self, forKey: .defaultFields) ?? []
            let fuzzyFields = try container.decodeIfPresent([TantivyQueryFuzzyField].self, forKey: .fuzzyFields) ?? []
            self = .queryString(TantivyQueryString(query: query, defaultFields: defaultFields, fuzzyFields: fuzzyFields))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown query type: \(type)"
            )
        }
    }
}

public struct TantivyQueryTerm: Codable, Sendable {
    public var name: String
    public var value: TantivyQueryValue

    public init(name: String, value: TantivyQueryValue) {
        self.name = name
        self.value = value
    }
}

public enum TantivyQueryValue: Codable, Sendable {
    case text(String)
    case u64(UInt64)
    case i64(Int64)
    case f64(Double)
    case bool(Bool)
    case date(Int64)
    case bytes(Data)
    case facet(String)
    case json(String)

    public static func from(date value: Date) -> TantivyQueryValue {
        let micros = Int64((value.timeIntervalSince1970 * 1_000_000).rounded())
        return .date(micros)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .value)
        case .u64(let value):
            try container.encode("u64", forKey: .type)
            try container.encode(value, forKey: .value)
        case .i64(let value):
            try container.encode("i64", forKey: .type)
            try container.encode(value, forKey: .value)
        case .f64(let value):
            try container.encode("f64", forKey: .type)
            try container.encode(value, forKey: .value)
        case .bool(let value):
            try container.encode("bool", forKey: .type)
            try container.encode(value, forKey: .value)
        case .date(let value):
            try container.encode("date", forKey: .type)
            try container.encode(value, forKey: .value)
        case .bytes(let value):
            try container.encode("bytes", forKey: .type)
            try container.encode([UInt8](value), forKey: .value)
        case .facet(let value):
            try container.encode("facet", forKey: .type)
            try container.encode(value, forKey: .value)
        case .json(let value):
            try container.encode("json", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .value))
        case "u64":
            self = .u64(try container.decode(UInt64.self, forKey: .value))
        case "i64":
            self = .i64(try container.decode(Int64.self, forKey: .value))
        case "f64":
            self = .f64(try container.decode(Double.self, forKey: .value))
        case "bool":
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case "date":
            self = .date(try container.decode(Int64.self, forKey: .value))
        case "bytes":
            let bytes = try container.decode([UInt8].self, forKey: .value)
            self = .bytes(Data(bytes))
        case "facet":
            self = .facet(try container.decode(String.self, forKey: .value))
        case "json":
            self = .json(try container.decode(String.self, forKey: .value))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown query value type: \(type)"
            )
        }
    }
}

public enum TantivyQueryOccur: String, Codable, Sendable {
    case must
    case should
    case mustNot = "must_not"
}

public struct TantivyBooleanClause: Codable, Sendable {
    public var occur: TantivyQueryOccur
    public var query: TantivyQuery

    public init(occur: TantivyQueryOccur, query: TantivyQuery) {
        self.occur = occur
        self.query = query
    }
}

public struct TantivyQueryString: Codable, Sendable {
    public var query: String
    public var defaultFields: [String]
    public var fuzzyFields: [TantivyQueryFuzzyField]

    public init(query: String, defaultFields: [String] = [], fuzzyFields: [TantivyQueryFuzzyField] = []) {
        self.query = query
        self.defaultFields = defaultFields
        self.fuzzyFields = fuzzyFields
    }

    private enum CodingKeys: String, CodingKey {
        case query
        case defaultFields = "default_fields"
        case fuzzyFields = "fuzzy_fields"
    }
}

public struct TantivyQueryFuzzyField: Codable, Sendable {
    public var fieldName: String
    public var prefix: Bool
    public var distance: UInt8
    public var transposeCostOne: Bool

    public init(fieldName: String, prefix: Bool = false, distance: UInt8 = 1, transposeCostOne: Bool = false) {
        self.fieldName = fieldName
        self.prefix = prefix
        self.distance = distance
        self.transposeCostOne = transposeCostOne
    }

    private enum CodingKeys: String, CodingKey {
        case fieldName = "field_name"
        case prefix
        case distance
        case transposeCostOne = "transpose_cost_one"
    }
}
