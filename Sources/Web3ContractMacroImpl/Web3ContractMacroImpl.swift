import SwiftCompilerPlugin
import SwiftCompilerPluginMessageHandling
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftDiagnostics
import Foundation
import SwiftParser

public struct Web3ContractMacro: MemberMacro {
//    public static func expansion(of node: some SwiftSyntax.FreestandingMacroExpansionSyntax, in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
//        let imp = try ImportDeclSyntax("import Web3Core")
//        return [DeclSyntax(imp)]
//    }
    public static func parseAbiString(_ node: AttributeSyntax) throws -> String {
        guard case let .argumentList(arguments) = node.arguments else {
            return "[]"
        }
        if let stringLiteralSytax = arguments.first?.expression.as(StringLiteralExprSyntax.self) {
            return stringLiteralSytax.segments.compactMap { syntax in
                if case let .stringSegment(str) = syntax {
                    return str.content.text
                }
                return nil
            }.joined()
        }
        return ""
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
//        guard case let .argumentList(arguments) = node.arguments else {
//            return []
//        }

        let abiString = try parseAbiString(node)

//        if let syntax = arguments.first?.expression.as(MemberAccessExprSyntax.self) {
//        }
//        guard let cls = declaration.as(ClassDeclSyntax.self) else {
//            return []
//        }

        guard let elements = try? parse(node, abiString) else {
            throw DiagnosticsError(diagnostics: [
                .init(node: node, message: Diagnostic.invalidJson(abiString))
            ])
        }
        print("elements.count: ", elements.count)

        let constants: [DeclSyntax] = [
            """
            private let abiString = \"""
                \(raw: abiString)
            \"""
            """,
            """
            private let contract: EthereumContract
            private let contractAddress: EthereumAddress
            private var web3: Web3
            """,
            """
            init(address: EthereumAddress, web3: Web3) {
                self.contractAddress = address
                self.web3 = web3
                self.contract = try! EthereumContract(abiString)
            }
            """
        ]

        var types = [ABI.StructName: [ABI.Element.InOut]]()
        elements.forEach { ele in
            if case let .function(fn) = ele {
                let res = extractAllStructs(fn.outputs.map { $0.type })
                types.merge(res, uniquingKeysWith: { a, b in a })
            }
        }
        let namespaces = types.keys.compactMap({ $0.namespace })
        let structsDecls = namespaces.flatMap { namespace in
            return types.filter { $0.key.namespace == namespace }.map { out -> DeclSyntax in
                let properties = out.value.map { input in
                    "public let \(input.name): \(input.type.typeName)"
                }.joined(separator: "\n")
                return """
                public struct \(raw: out.key.identifier) {
                    \(raw: properties)
                }
                """
            }
        }

        return constants + structsDecls + elements.compactMap { ele -> DeclSyntax? in
            if case let .event(event) = ele {
                return buildEvent(event)
            }
            if case let .error(ethError) = ele {
                return buildError(ethError)
            }
            if case let .function(fn) = ele {
                return buildNonPayableFunc(fn, types: types)
            }
            return nil
        }
    }
    
    static func parse(_ node: SyntaxProtocol, _ abiString: String) throws -> [ABI.Element] {
        let jsonData = abiString.data(using: .utf8)
        let abi = try JSONDecoder().decode([ABI.Record].self, from: jsonData!)
        let abiNative = try abi.map({ record -> ABI.Element in
            return try record.parse()
        })
        return abiNative
    }

    static func extractAllStructs(_ outs: [ABI.Element.ParameterType]) -> [ABI.StructName: [ABI.Element.InOut]] {
        var result = [ABI.StructName: [ABI.Element.InOut]]()
        outs.forEach { out in
            if case let .tuple(params, structName) = out, let structName = structName {
                result[structName] = params
            }
            if case let .array(type, _) = out {
                result.merge(extractAllStructs([type]), uniquingKeysWith: { a, b in a })
            }
        }
        return result
    }
}

extension Web3ContractMacro {
    static func buildNonPayableFunc(_ fn: ABI.Element.Function, types: [ABI.StructName: [ABI.Element.InOut]] = [:]) -> DeclSyntax? {
        func buildSingleReturnType() -> String {
            if case let .tuple(types: _, structName: name) = fn.outputs.first!.type {
                if let _ = types.first(where: { $0.key.identifier == name?.identifier }) {
                    return " -> \(name!.identifier)"
                }
            }
            if case let .array(type, _) = fn.outputs.first!.type, case let .tuple(types: _, structName: name) = type {
                if let _ = types.first(where: { $0.key.identifier == name?.identifier }) {
                    return " -> [\(name!.identifier)]"
                }
            }
            return " -> \(fn.outputs.first!.type.typeName)"
        }

        func buildSingleReturnSyntax() -> String {
            if case let .tuple(types: _, structName: name) = fn.outputs.first!.type {
                return ""
            }
            if case let .array(type, _) = fn.outputs.first!.type, case let .tuple(types, structName: name) = type {
                let initParams = (0..<types.count).map { idx in
                    "\(types[idx].name): obj[\(idx)] as! \(types[idx].type.typeName)"
                }.joined(separator: ", \n")
                return """
                let objects = result["0"] as! [[Any]]
                return objects.map { obj in
                    \(name!.identifier)(
                        \(initParams)
                    )
                }
                """
            }
            return "return result[\"0\"] as! \(fn.outputs.first!.type.typeName)"
        }

        func buildTupleReturnType() -> String {
            if fn.outputs.filter({ $0.name.isEmpty }).isEmpty {
                return "-> (" + fn.outputs.map { out in
                    "\(out.name): \(out.type.typeName)"
                }.joined(separator: ", ") + ")"
            } else {
                return "-> (" + fn.outputs.map { "\($0.type.typeName)" }.joined(separator: ", ") + ")"
            }
        }

        guard let name = fn.name else { return nil }

        let parameters = fn.inputs.map { input in
            (input.name, input.type.typeName)
        }
        let fnParam = parameters.map({ "\($0.0): \($0.1)" }).joined(separator: ", ")
        let encodeParam = parameters.map({ $0.0 }).joined(separator: ", ")

        let signature = "\(name)(\(fn.inputs.map { $0.type.abiRepresentation }.joined(separator: ",")))"
        let returnType: String = if fn.outputs.isEmpty {
            ""
        } else if fn.outputs.count == 1 {
            buildSingleReturnType()
        } else {
            if fn.outputs.count <= 3 {
                buildTupleReturnType()
            } else {
                "-> [String: Any]"
            }
        }
        let returnSyntax = if fn.outputs.isEmpty {
            ""
        } else if fn.outputs.count == 1 {
            buildSingleReturnSyntax()
        } else {
            if fn.outputs.count <= 3 {
                """
                return (\(fn.outputs.enumerated().map({ ele in
                        "result[\"\(ele.offset)\"] as! \(ele.element.type.typeName)"
                    }).joined(separator: ", ")))
                """
            } else {
                "return result as! [String: Any]"
            }
        }
        return """
        func \(raw: name)(\(raw: fnParam)) async throws\(raw: returnType) {
            let method = contract.methods["\(raw: signature)"]!.first!
            let data = method.encodeParameters([\(raw: encodeParam)])
            let transaction = CodableTransaction(to: contractAddress, data: data!)
            let returnData = try await web3.eth.callTransaction(transaction)
            let result = try method.decodeReturnData(returnData)
            \(raw: returnSyntax)
        }
        """
    }

    static func buildEvent(_ event: ABI.Element.Event) -> DeclSyntax {
        let properties = event.inputs.map { input in
            "let \(input.name): \(input.type.typeName)"
        }.joined(separator: "\n")
        return """
        struct \(raw: event.name) {
            \(raw: properties)
        }
        """
    }

    static func buildError(_ err: ABI.Element.EthError) -> DeclSyntax {
        let properties = err.inputs.map { input in
            "let \(input.name): \(input.type.typeName)"
        }.joined(separator: "\n")
        return """
        struct \(raw: err.name): Error {
            \(raw: properties)
        }
        """
    }
}

extension ABI.Element.ParameterType {
    var typeName: String {
        switch self {
        case .uint:
            "BigUInt"
        case .int:
            "BigInt"
        case .address:
            "EthereumAddress"
        case .function:
            ""
        case .bool:
            "Bool"
        case .bytes:
            "Data"
        case .array(let type, _):
            "[\(type.typeName)]"
        case .dynamicBytes:
            "Data"
        case .string:
            "String"
        case .tuple(let types, _):
            "(" + types.map(\.type).map(\.typeName).joined(separator: ", ") + ")"
        }
    }
}

extension ABI.Element.ParameterType {
    public var abiRepresentation: String {
        switch self {
        case .uint(let bits):
            return "uint\(bits)"
        case .int(let bits):
            return "int\(bits)"
        case .address:
            return "address"
        case .bool:
            return "bool"
        case .bytes(let length):
            return "bytes\(length)"
        case .dynamicBytes:
            return "bytes"
        case .function:
            return "function"
        case .array(type: let type, length: let length):
            if length == 0 {
                return  "\(type.abiRepresentation)[]"
            }
            return "\(type.abiRepresentation)[\(length)]"
        case .tuple(types: let types, _):
            let typesRepresentation = types.map(\.type).map(\.abiRepresentation)
            let typesJoined = typesRepresentation.joined(separator: ",")
            return "(\(typesJoined))"
        case .string:
            return "string"
        }
    }
}
