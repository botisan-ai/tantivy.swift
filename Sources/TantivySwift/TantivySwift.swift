import Foundation

public protocol TantivySearchableDocument {
    associatedtype CodingKeys: CodingKey
}

public struct TantivySwiftSearchQuery<TantivyDoc: TantivySearchableDocument & Sendable>: Sendable {
    public var queryStr: String
    public var defaultFields: [TantivyDoc.CodingKeys]
    public var fuzzyFields: [TantivySwiftFuzzyField<TantivyDoc>]
    public var limit: UInt32
    public var offset: UInt32

    public init(
        queryStr: String,
        defaultFields: [TantivyDoc.CodingKeys] = [],
        fuzzyFields: [TantivySwiftFuzzyField<TantivyDoc>] = [],
        limit: UInt32 = 10,
        offset: UInt32 = 0
    ) {
        self.queryStr = queryStr
        self.defaultFields = defaultFields
        self.fuzzyFields = fuzzyFields
        self.limit = limit
        self.offset = offset
    }

    func toTantivyQuery() -> TantivyQuery {
        return .queryString(
            TantivyQueryString(
                query: queryStr,
                defaultFields: defaultFields.map { $0.stringValue },
                fuzzyFields: fuzzyFields.map { $0.toQueryFuzzyField() }
            )
        )
    }
}

public struct TantivySwiftFuzzyField<TantivyDoc: TantivySearchableDocument & Sendable>: Sendable {
    public var field: TantivyDoc.CodingKeys
    public var prefix: Bool = false
    public var distance: UInt8 = 1
    public var transposeCostOne: Bool = false

    public init(
        field: TantivyDoc.CodingKeys,
        prefix: Bool = false,
        distance: UInt8 = 1,
        transposeCostOne: Bool = false
    ) {
        self.field = field
        self.prefix = prefix
        self.distance = distance
        self.transposeCostOne = transposeCostOne
    }

    func toQueryFuzzyField() -> TantivyQueryFuzzyField {
        return TantivyQueryFuzzyField(
            fieldName: field.stringValue,
            prefix: prefix,
            distance: distance,
            transposeCostOne: transposeCostOne
        )
    }
}

// search result struct
// building this struct in Swift so it can use generics
public struct TantivySearchResults<TantivyDoc: TantivySearchableDocument & Sendable>: Sendable {
    public let count: UInt64
    public let docs: [TantivySearchResult<TantivyDoc>]
}

public struct TantivySearchResult<TantivyDoc: TantivySearchableDocument & Sendable>: Sendable {
    public let score: Float
    public let doc: TantivyDoc
}
