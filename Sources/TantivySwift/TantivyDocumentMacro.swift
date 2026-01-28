@attached(member, names: named(schemaTemplate), named(CodingKeys), named(init(from:)), named(init(fromFields:)), named(encode(to:)), named(toTantivyDocument))
@attached(extension, conformances: TantivyDocument)
public macro TantivyDocument() = #externalMacro(module: "TantivySwiftMacros", type: "TantivyDocumentMacro")
