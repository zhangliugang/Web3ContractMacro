import SwiftCompilerPlugin
import SwiftCompilerPluginMessageHandling
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftDiagnostics
import Foundation
import SwiftParser
import Web3ContractParser

public struct Web3ContractMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard case let .argumentList(arguments) = node.arguments, let stringLiteralSytax = arguments.first?.expression.as(StringLiteralExprSyntax.self) else {
            return []
        }

        let string = stringLiteralSytax.segments.compactMap { syntax in
            if case let .stringSegment(str) = syntax {
                return str.content.text
            }
            return nil
        }.joined()

        return try parseAbiString(string)
    }
}
