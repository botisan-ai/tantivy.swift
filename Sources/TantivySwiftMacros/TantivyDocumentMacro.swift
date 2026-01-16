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
        declarations.append(generateInitFromDecoder(fields: fields, structName: structName))
        declarations.append(generateEncodeToEncoder(fields: fields))
        declarations.append(generateSchemaTemplate(fields: fields, structName: structName))
        
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
                    if ["IDField", "TextField", "U64Field", "I64Field", "F64Field", "BoolField", "DateField", "BytesField"].contains(name) {
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
    
    private static func generateInitFromDecoder(fields: [FieldInfo], structName: String) -> DeclSyntax {
        var lines: [String] = []
        lines.append("let container = try decoder.container(keyedBy: CodingKeys.self)")
        
        for field in fields {
            let decodeLine = generateDecodeLine(for: field)
            lines.append(decodeLine)
        }
        
        let body = lines.joined(separator: "\n        ")
        return """
            public init(from decoder: Decoder) throws {
                \(raw: body)
            }
            """
    }
    
    private static func generateDecodeLine(for field: FieldInfo) -> String {
        let name = field.name
        let type = field.type
        let wrapper = field.wrapperType ?? "TextField"
        
        switch wrapper {
        case "IDField", "TextField":
            if type == "String" {
                return "_\(name) = \(wrapper)(wrappedValue: try container.decode([String].self, forKey: .\(name)).first ?? \"\")"
            } else if type.hasSuffix("?") {
                let innerType = String(type.dropLast())
                return "_\(name) = \(wrapper)(wrappedValue: try container.decodeIfPresent([\(innerType)].self, forKey: .\(name))?.first)"
            } else {
                return "_\(name) = \(wrapper)(wrappedValue: try container.decode([String].self, forKey: .\(name)).first ?? \"\")"
            }
            
        case "U64Field":
            if type.hasSuffix("?") {
                return "_\(name) = \(wrapper)(wrappedValue: try container.decodeIfPresent([UInt64].self, forKey: .\(name))?.first)"
            }
            return "_\(name) = \(wrapper)(wrappedValue: try container.decode([UInt64].self, forKey: .\(name)).first ?? 0)"
            
        case "I64Field":
            if type.hasSuffix("?") {
                return "_\(name) = \(wrapper)(wrappedValue: try container.decodeIfPresent([Int64].self, forKey: .\(name))?.first)"
            }
            return "_\(name) = \(wrapper)(wrappedValue: try container.decode([Int64].self, forKey: .\(name)).first ?? 0)"
            
        case "F64Field":
            if type.hasSuffix("?") {
                return "_\(name) = \(wrapper)(wrappedValue: try container.decodeIfPresent([Double].self, forKey: .\(name))?.first)"
            }
            return "_\(name) = \(wrapper)(wrappedValue: try container.decode([Double].self, forKey: .\(name)).first ?? 0.0)"
            
        case "BoolField":
            if type.hasSuffix("?") {
                return "_\(name) = \(wrapper)(wrappedValue: try container.decodeIfPresent([Bool].self, forKey: .\(name))?.first)"
            }
            return "_\(name) = \(wrapper)(wrappedValue: try container.decode([Bool].self, forKey: .\(name)).first ?? false)"
            
        case "DateField":
            if type.hasSuffix("?") {
                return """
                if let dateStr = try container.decodeIfPresent([String].self, forKey: .\(name))?.first {
                            _\(name) = \(wrapper)(wrappedValue: ISO8601DateFormatter().date(from: dateStr))
                        } else {
                            _\(name) = \(wrapper)(wrappedValue: nil)
                        }
                """
            }
            return """
            let \(name)Str = try container.decode([String].self, forKey: .\(name)).first ?? ""
                    _\(name) = \(wrapper)(wrappedValue: ISO8601DateFormatter().date(from: \(name)Str) ?? Date(timeIntervalSince1970: 0))
            """
            
        case "BytesField":
            if type.hasSuffix("?") {
                return "_\(name) = \(wrapper)(wrappedValue: try container.decodeIfPresent([Data].self, forKey: .\(name))?.first)"
            }
            return "_\(name) = \(wrapper)(wrappedValue: try container.decode([Data].self, forKey: .\(name)).first ?? Data())"
            
        default:
            return "_\(name) = \(wrapper)(wrappedValue: try container.decode([String].self, forKey: .\(name)).first ?? \"\")"
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
