import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct TantivyDocumentMacro: MemberMacro, ExtensionMacro {
    
    struct FieldInfo {
        let name: String
        let type: String
        let wrapperType: String?
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.notAStruct
        }
        
        let fields = extractFields(from: structDecl)
        let structName = structDecl.name.text
        
        var declarations: [DeclSyntax] = []
        
        declarations.append(generateCodingKeys(fields: fields))
        declarations.append(generateEncodeToEncoder(fields: fields))
        declarations.append(generateSchemaTemplate(fields: fields, structName: structName))
        declarations.append(generateInitFromFields(fields: fields))
        declarations.append(generateToTantivyDocument(fields: fields))
        
        return declarations
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let extensionDecl = try ExtensionDeclSyntax("extension \(type): TantivyDocument {}")
        return [extensionDecl]
    }
    
    private static func extractFields(from structDecl: StructDeclSyntax) -> [FieldInfo] {
        var fields: [FieldInfo] = []
        
        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation?.type else {
                continue
            }
            
            let fieldName = identifier.identifier.text
            let typeName = typeAnnotation.trimmedDescription
            
            var wrapperType: String? = nil
            for attribute in varDecl.attributes {
                if let attr = attribute.as(AttributeSyntax.self),
                   let attrName = attr.attributeName.as(IdentifierTypeSyntax.self) {
                    let name = attrName.name.text
                    if ["IDField", "TextField", "U64Field", "I64Field", "F64Field", "BoolField", "DateField", "BytesField", "FacetField", "JsonField"].contains(name) {
                        wrapperType = name
                        break
                    }
                }
            }
            
            if wrapperType != nil {
                fields.append(FieldInfo(name: fieldName, type: typeName, wrapperType: wrapperType))
            }
        }
        
        return fields
    }
    
    private static func generateCodingKeys(fields: [FieldInfo]) -> DeclSyntax {
        let cases = fields.map { "case \($0.name)" }.joined(separator: "\n        ")
        return """
            enum CodingKeys: String, CodingKey {
                \(raw: cases)
            }
            """
    }
    
    private static func generateInitFromFields(fields: [FieldInfo]) -> DeclSyntax {
        var lines: [String] = []
        lines.append("let map = TantivyDocumentFieldMap(fields)")

        for field in fields {
            lines.append(generateInitFromFieldsLine(for: field))
        }

        let body = lines.joined(separator: "\n        ")
        return """
            public init(fromFields fields: TantivyDocumentFields) throws {
                \(raw: body)
            }
            """
    }

    private static func generateInitFromFieldsLine(for field: FieldInfo) -> String {
        let name = field.name
        let type = field.type
        let wrapper = field.wrapperType ?? "TextField"
        let isOptional = isOptionalType(type)
        let isArray = isArrayType(type)
        let isStringArray = isStringArrayType(type)

        switch wrapper {
        case "IDField":
            if isStringArray {
                if isOptional {
                    return "_\(name) = \(wrapper)(wrappedValue: { let values = map.texts(\"\(name)\"); return values.isEmpty ? nil : values }())"
                }
                return "_\(name) = \(wrapper)(wrappedValue: map.texts(\"\(name)\"))"
            }
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.text(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.text(\"\(name)\") ?? \"\")"

        case "TextField":
            if isStringArray {
                if isOptional {
                    return "_\(name) = \(wrapper)(wrappedValue: { let values = map.texts(\"\(name)\"); return values.isEmpty ? nil : values }())"
                }
                return "_\(name) = \(wrapper)(wrappedValue: map.texts(\"\(name)\"))"
            }
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.text(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.text(\"\(name)\") ?? \"\")"

        case "U64Field":
            if isArray {
                if isOptional {
                    return "_\(name) = \(wrapper)(wrappedValue: { let values = map.u64s(\"\(name)\"); return values.isEmpty ? nil : values }())"
                }
                return "_\(name) = \(wrapper)(wrappedValue: map.u64s(\"\(name)\"))"
            }
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.u64(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.u64(\"\(name)\") ?? 0)"

        case "I64Field":
            if isArray {
                if isOptional {
                    return "_\(name) = \(wrapper)(wrappedValue: { let values = map.i64s(\"\(name)\"); return values.isEmpty ? nil : values }())"
                }
                return "_\(name) = \(wrapper)(wrappedValue: map.i64s(\"\(name)\"))"
            }
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.i64(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.i64(\"\(name)\") ?? 0)"

        case "F64Field":
            if isArray {
                if isOptional {
                    return "_\(name) = \(wrapper)(wrappedValue: { let values = map.f64s(\"\(name)\"); return values.isEmpty ? nil : values }())"
                }
                return "_\(name) = \(wrapper)(wrappedValue: map.f64s(\"\(name)\"))"
            }
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.f64(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.f64(\"\(name)\") ?? 0.0)"

        case "BoolField":
            if isArray {
                if isOptional {
                    return "_\(name) = \(wrapper)(wrappedValue: { let values = map.bools(\"\(name)\"); return values.isEmpty ? nil : values }())"
                }
                return "_\(name) = \(wrapper)(wrappedValue: map.bools(\"\(name)\"))"
            }
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.bool(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.bool(\"\(name)\") ?? false)"

        case "DateField":
            if isArray {
                if isOptional {
                    return "_\(name) = \(wrapper)(wrappedValue: { let values = map.dates(\"\(name)\"); return values.isEmpty ? nil : values }())"
                }
                return "_\(name) = \(wrapper)(wrappedValue: map.dates(\"\(name)\"))"
            }
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.date(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.date(\"\(name)\") ?? Date(timeIntervalSince1970: 0))"

        case "BytesField":
            if isArray {
                if isOptional {
                    return "_\(name) = \(wrapper)(wrappedValue: { let values = map.bytesValues(\"\(name)\"); return values.isEmpty ? nil : values }())"
                }
                return "_\(name) = \(wrapper)(wrappedValue: map.bytesValues(\"\(name)\"))"
            }
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.bytes(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.bytes(\"\(name)\") ?? Data())"

        case "FacetField":
            if isStringArray {
                if isOptional {
                    return "_\(name) = \(wrapper)(wrappedValue: { let values = map.facets(\"\(name)\"); return values.isEmpty ? nil : values }())"
                }
                return "_\(name) = \(wrapper)(wrappedValue: map.facets(\"\(name)\"))"
            }
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.facet(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.facet(\"\(name)\") ?? \"\")"

        case "JsonField":
            if isArray {
                let elementType = arrayElementType(type) ?? "String"
                if isOptional {
                    return "_\(name) = \(wrapper)(wrappedValue: try { let values = try map.jsons(\"\(name)\").map { try TantivyJsonCoding.decode(\(elementType).self, from: $0) }; return values.isEmpty ? nil : values }())"
                }
                return "_\(name) = \(wrapper)(wrappedValue: try map.jsons(\"\(name)\").map { try TantivyJsonCoding.decode(\(elementType).self, from: $0) })"
            }
            if isOptional {
                let innerType = unwrapOptionalType(type)
                return "_\(name) = \(wrapper)(wrappedValue: try TantivyJsonCoding.decodeIfPresent(\(innerType).self, from: map.json(\"\(name)\")))"
            }
            let defaultValue = getDefaultValue(for: type)
            return """
            if let jsonValue = map.json("\(name)") {
                        _\(name) = \(wrapper)(wrappedValue: try TantivyJsonCoding.decode(\(type).self, from: jsonValue))
                    } else {
                        _\(name) = \(wrapper)(wrappedValue: \(defaultValue))
                    }
            """

        default:
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.text(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.text(\"\(name)\") ?? \"\")"
        }
    }
    
    private static func generateEncodeToEncoder(fields: [FieldInfo]) -> DeclSyntax {
        var lines: [String] = []
        lines.append("var container = encoder.container(keyedBy: CodingKeys.self)")
        
        for field in fields {
            let encodeLine = generateEncodeLine(for: field)
            lines.append(encodeLine)
        }
        
        let body = lines.joined(separator: "\n        ")
        return """
            public func encode(to encoder: Encoder) throws {
                \(raw: body)
            }
            """
    }
    
    private static func generateEncodeLine(for field: FieldInfo) -> String {
        let name = field.name
        let type = field.type
        let wrapper = field.wrapperType ?? "TextField"
        let isOptional = isOptionalType(type)
        let isArray = isArrayType(type)

        switch wrapper {
        case "DateField":
            if isArray {
                if isOptional {
                    return """
                    if let \(name)Values = \(name) {
                                try container.encode(\(name)Values.map { ISO8601DateFormatter().string(from: $0) }, forKey: .\(name))
                            }
                    """
                }
                return "try container.encode(\(name).map { ISO8601DateFormatter().string(from: $0) }, forKey: .\(name))"
            }
            if isOptional {
                return """
                if let \(name)Value = \(name) {
                            try container.encode(ISO8601DateFormatter().string(from: \(name)Value), forKey: .\(name))
                        }
                """
            }
            return "try container.encode(ISO8601DateFormatter().string(from: \(name)), forKey: .\(name))"

        default:
            if isOptional {
                return "try container.encodeIfPresent(\(name), forKey: .\(name))"
            }
            return "try container.encode(\(name), forKey: .\(name))"
        }
    }
    
    private static func generateSchemaTemplate(fields: [FieldInfo], structName: String) -> DeclSyntax {
        let initArgs = fields.map { field -> String in
            let defaultValue = getDefaultValue(for: field.type)
            return "\(field.name): \(defaultValue)"
        }.joined(separator: ", ")
        
        return """
            public static func schemaTemplate() -> \(raw: structName) {
                return \(raw: structName)(\(raw: initArgs))
            }
            """
    }

    private static func generateToTantivyDocument(fields: [FieldInfo]) -> DeclSyntax {
        var lines: [String] = []
        lines.append("var fields: [DocumentField] = []")

        for field in fields {
            lines.append(generateFieldAppend(for: field))
        }

        lines.append("return TantivyDocumentFields(fields: fields)")

        let body = lines.joined(separator: "\n        ")
        return """
            public func toTantivyDocument() throws -> TantivyDocumentFields {
                \(raw: body)
            }
            """
    }

    private static func generateFieldAppend(for field: FieldInfo) -> String {
        let name = field.name
        let wrapper = field.wrapperType ?? "TextField"
        let isOptional = isOptionalType(field.type)
        let isArray = isArrayType(field.type)
        let isStringArray = isStringArrayType(field.type)
        let valueName = isOptional ? "value" : name

        if wrapper == "JsonField" {
            if isArray {
                if isOptional {
                    return "if let values = \(name) { for value in values { let jsonString = try TantivyJsonCoding.encode(value); fields.append(DocumentField(name: \"\(name)\", value: .json(jsonString))) } }"
                }
                return "for value in \(name) { let jsonString = try TantivyJsonCoding.encode(value); fields.append(DocumentField(name: \"\(name)\", value: .json(jsonString))) }"
            }
            if isOptional {
                return """
                if let value = \(name) {
                            let jsonString = try TantivyJsonCoding.encode(value)
                            fields.append(DocumentField(name: "\(name)", value: .json(jsonString)))
                        }
                """
            }
            return """
            let jsonString = try TantivyJsonCoding.encode(\(name))
                    fields.append(DocumentField(name: "\(name)", value: .json(jsonString)))
            """
        }

        if (wrapper == "IDField" || wrapper == "TextField"), isStringArray {
            if isOptional {
                return "if let values = \(name) { for value in values { fields.append(DocumentField(name: \"\(name)\", value: .text(value))) } }"
            }
            return "for value in \(name) { fields.append(DocumentField(name: \"\(name)\", value: .text(value))) }"
        }

        if wrapper == "U64Field", isArray {
            if isOptional {
                return "if let values = \(name) { for value in values { fields.append(DocumentField(name: \"\(name)\", value: .u64(UInt64(value)))) } }"
            }
            return "for value in \(name) { fields.append(DocumentField(name: \"\(name)\", value: .u64(UInt64(value)))) }"
        }

        if wrapper == "I64Field", isArray {
            if isOptional {
                return "if let values = \(name) { for value in values { fields.append(DocumentField(name: \"\(name)\", value: .i64(Int64(value)))) } }"
            }
            return "for value in \(name) { fields.append(DocumentField(name: \"\(name)\", value: .i64(Int64(value)))) }"
        }

        if wrapper == "F64Field", isArray {
            if isOptional {
                return "if let values = \(name) { for value in values { fields.append(DocumentField(name: \"\(name)\", value: .f64(Double(value)))) } }"
            }
            return "for value in \(name) { fields.append(DocumentField(name: \"\(name)\", value: .f64(Double(value)))) }"
        }

        if wrapper == "BoolField", isArray {
            if isOptional {
                return "if let values = \(name) { for value in values { fields.append(DocumentField(name: \"\(name)\", value: .bool(value))) } }"
            }
            return "for value in \(name) { fields.append(DocumentField(name: \"\(name)\", value: .bool(value))) }"
        }

        if wrapper == "DateField", isArray {
            if isOptional {
                return "if let values = \(name) { for value in values { fields.append(DocumentField(name: \"\(name)\", value: .date(Int64((value.timeIntervalSince1970 * 1_000_000).rounded())))) } }"
            }
            return "for value in \(name) { fields.append(DocumentField(name: \"\(name)\", value: .date(Int64((value.timeIntervalSince1970 * 1_000_000).rounded())))) }"
        }

        if wrapper == "BytesField", isArray {
            if isOptional {
                return "if let values = \(name) { for value in values { fields.append(DocumentField(name: \"\(name)\", value: .bytes(value))) } }"
            }
            return "for value in \(name) { fields.append(DocumentField(name: \"\(name)\", value: .bytes(value))) }"
        }

        if wrapper == "FacetField", isStringArray {
            if isOptional {
                return "if let values = \(name) { for value in values { fields.append(DocumentField(name: \"\(name)\", value: .facet(value))) } }"
            }
            return "for value in \(name) { fields.append(DocumentField(name: \"\(name)\", value: .facet(value))) }"
        }

        let valueExpr: String
        switch wrapper {
        case "IDField", "TextField":
            valueExpr = ".text(\(valueName))"
        case "U64Field":
            valueExpr = ".u64(UInt64(\(valueName)))"
        case "I64Field":
            valueExpr = ".i64(Int64(\(valueName)))"
        case "F64Field":
            valueExpr = ".f64(Double(\(valueName)))"
        case "BoolField":
            valueExpr = ".bool(\(valueName))"
        case "DateField":
            valueExpr = ".date(Int64((\(valueName).timeIntervalSince1970 * 1_000_000).rounded()))"
        case "BytesField":
            valueExpr = ".bytes(\(valueName))"
        case "FacetField":
            valueExpr = ".facet(String(describing: \(valueName)))"
        default:
            valueExpr = ".text(String(describing: \(valueName)))"
        }

        if isOptional {
            return "if let value = \(name) { fields.append(DocumentField(name: \"\(name)\", value: \(valueExpr))) }"
        }
        return "fields.append(DocumentField(name: \"\(name)\", value: \(valueExpr)))"
    }
    
    private static func normalizedType(_ typeName: String) -> String {
        return typeName.replacingOccurrences(of: " ", with: "")
    }

    private static func isOptionalType(_ typeName: String) -> Bool {
        let normalized = normalizedType(typeName)
        return normalized.hasSuffix("?")
    }

    private static func unwrapOptionalType(_ typeName: String) -> String {
        let normalized = normalizedType(typeName)
        if normalized.hasSuffix("?") {
            return String(normalized.dropLast())
        }
        return normalized
    }

    private static func arrayElementType(_ typeName: String) -> String? {
        let baseType = unwrapOptionalType(typeName)

        if baseType.hasPrefix("[") && baseType.hasSuffix("]") {
            let inner = baseType.dropFirst().dropLast()
            return String(inner)
        }

        let prefix = "Array<"
        if baseType.hasPrefix(prefix) && baseType.hasSuffix(">") {
            let inner = baseType.dropFirst(prefix.count).dropLast()
            return String(inner)
        }

        return nil
    }

    private static func isArrayType(_ typeName: String) -> Bool {
        return arrayElementType(typeName) != nil
    }

    private static func isStringType(_ typeName: String) -> Bool {
        let normalized = normalizedType(typeName)
        return normalized == "String" || normalized == "Swift.String"
    }

    private static func isStringArrayType(_ typeName: String) -> Bool {
        guard let elementType = arrayElementType(typeName) else {
            return false
        }
        return isStringType(elementType)
    }

    private static func getDefaultValue(for typeName: String) -> String {
        if isOptionalType(typeName) {
            return "nil"
        }
        
        switch typeName {
        case "String":
            return "\"\""
        case "Int", "Int8", "Int16", "Int32", "Int64":
            return "0"
        case "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return "0"
        case "Double", "Float":
            return "0.0"
        case "Bool":
            return "false"
        case "Date":
            return "Date(timeIntervalSince1970: 0)"
        case "Data":
            return "Data()"
        default:
            if typeName.hasPrefix("[") && typeName.hasSuffix("]") {
                return "[]"
            }
            return "\(typeName)()"
        }
    }
}

enum MacroError: Error, CustomStringConvertible {
    case notAStruct
    
    var description: String {
        switch self {
        case .notAStruct:
            return "@TantivyDocument can only be applied to structs"
        }
    }
}

@main
struct TantivySwiftMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        TantivyDocumentMacro.self,
    ]
}
