import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct TantivyMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        TantivyDocumentMacro.self,
    ]
}

public struct TantivyDocumentMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.notAStruct
        }
        
        let structName = structDecl.name.text
        
        var fieldInitializers: [String] = []
        var codingKeysCases: [String] = []
        
        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            
            let fieldName = identifier.identifier.text
            
            let hasSchemaAttribute = varDecl.attributes.contains { attr in
                guard let attrSyntax = attr.as(AttributeSyntax.self),
                      let identifierType = attrSyntax.attributeName.as(IdentifierTypeSyntax.self) else {
                    return false
                }
                let name = identifierType.name.text
                return ["TextField", "IDField", "UInt64Field", "Int64Field", 
                        "DoubleField", "DateField", "BoolField"].contains(name)
            }
            
            if hasSchemaAttribute {
                codingKeysCases.append(fieldName)
                
                if let typeAnnotation = binding.typeAnnotation?.type {
                    let typeName = typeAnnotation.description.trimmingCharacters(in: .whitespaces)
                    let defaultValue = Self.defaultValue(for: typeName)
                    fieldInitializers.append("\(fieldName): \(defaultValue)")
                }
            }
        }
        
        let codingKeysEnum: DeclSyntax = """
            enum CodingKeys: String, CodingKey {
                case \(raw: codingKeysCases.joined(separator: ", "))
            }
            """
        
        let schemaTemplate: DeclSyntax = """
            static var schemaTemplate: Self {
                \(raw: structName)(\(raw: fieldInitializers.joined(separator: ", ")))
            }
            """
        
        return [codingKeysEnum, schemaTemplate]
    }
    
    private static func defaultValue(for typeName: String) -> String {
        switch typeName {
        case "String":
            return "\"\""
        case "Int", "Int64":
            return "0"
        case "UInt64":
            return "0"
        case "Double", "Float":
            return "0.0"
        case "Bool":
            return "false"
        case "Date":
            return "Date()"
        case "String?":
            return "nil"
        case "[String]":
            return "[]"
        default:
            if typeName.hasSuffix("?") {
                return "nil"
            }
            if typeName.hasPrefix("[") && typeName.hasSuffix("]") {
                return "[]"
            }
            return ".init()"
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
