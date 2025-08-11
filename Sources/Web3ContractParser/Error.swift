//
//  Error.swift
//  Web3ContractMacro
//
//  Created by liugang zhang on 2025/8/10.
//

import SwiftSyntax

func generateErrorSyntax(_ err: ABI.Element.EthError) -> DeclSyntax {
    let properties: [DeclSyntax] = err.inputs.map { input in
        "let \(raw: input.name): \(raw: input.type.typeName)"
    }
    let memberBlock = buildMemberList(properties)
    return DeclSyntax(
        StructDeclSyntax(
            leadingTrivia: Trivia.newline,
            name: .identifier(err.name),
            inheritanceClause: buildInheritanceList(["Error"]),
            memberBlock: memberBlock,
            trailingTrivia: Trivia.newline
        )
    )
}
