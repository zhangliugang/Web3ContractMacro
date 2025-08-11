//
//  Event.swift
//  Web3ContractMacro
//
//  Created by liugang zhang on 2025/8/10.
//

import SwiftSyntax

func generateEventSyntax(_ event: ABI.Element.Event, modifier: DeclModifierListSyntax) -> DeclSyntax {
    let properties: [DeclSyntax] = event.inputs.map { input in
        "let \(raw: input.name): \(raw: input.type.typeName)"
    }
    let memberBlock = buildMemberList(properties)

    return DeclSyntax(
        StructDeclSyntax(
            leadingTrivia: Trivia.newline,
            modifiers: modifier,
            name: .identifier(event.name),
            memberBlock: memberBlock,
            trailingTrivia: Trivia.newline
        )
    )
}
