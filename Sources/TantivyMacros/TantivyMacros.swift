@attached(member, names: named(CodingKeys), named(schemaTemplate))
public macro TantivyDocument() = #externalMacro(module: "TantivyMacrosPlugin", type: "TantivyDocumentMacro")
