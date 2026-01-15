@attached(member, names: named(schemaTemplate), named(CodingKeys), named(init(from:)), named(encode(to:)))
@attached(extension, conformances: TantivyDocument)
public macro TantivyDocument() = #externalMacro(module: "TantivySwiftMacros", type: "TantivyDocumentMacro")
