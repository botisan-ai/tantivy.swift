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
        let isOptional = type.hasSuffix("?")

        switch wrapper {
        case "IDField", "TextField":
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.text(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.text(\"\(name)\") ?? \"\")"

        case "U64Field":
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.u64(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.u64(\"\(name)\") ?? 0)"

        case "I64Field":
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.i64(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.i64(\"\(name)\") ?? 0)"

        case "F64Field":
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.f64(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.f64(\"\(name)\") ?? 0.0)"

        case "BoolField":
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.bool(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.bool(\"\(name)\") ?? false)"

        case "DateField":
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.date(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.date(\"\(name)\") ?? Date(timeIntervalSince1970: 0))"

        case "BytesField":
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.bytes(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.bytes(\"\(name)\") ?? Data())"

        case "FacetField":
            if isOptional {
                return "_\(name) = \(wrapper)(wrappedValue: map.facet(\"\(name)\"))"
            }
            return "_\(name) = \(wrapper)(wrappedValue: map.facet(\"\(name)\") ?? \"\")"

        case "JsonField":
            if isOptional {
                let innerType = String(type.dropLast())
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
        let isOptional = type.hasSuffix("?")
        
        switch wrapper {
        case "DateField":
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
        let isOptional = field.type.hasSuffix("?")
        let valueName = isOptional ? "value" : name

        if wrapper == "JsonField" {
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
            valueExpr = ".bytes([UInt8](\(valueName)))"
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
    
    private static func getDefaultValue(for typeName: String) -> String {
        if typeName.hasSuffix("?") {
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
