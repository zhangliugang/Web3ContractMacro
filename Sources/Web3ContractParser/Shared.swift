//
//  Shared.swift
//  Web3ContractMacro
//
//  Created by liugang zhang on 2025/8/10.
//

import SwiftSyntax

func buildMember(key: String, type: String, modifier: DeclModifierListSyntax) -> DeclSyntax {
    DeclSyntax (
        VariableDeclSyntax(
            modifiers: modifier,
            bindingSpecifier: .keyword(.let),
            bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(key)),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(),
                        type: IdentifierTypeSyntax(
                            name: TokenSyntax.identifier(type),
                        )
                    )
                )
            }
        )
    )
}

func buildMemberList(_ syntaxs: [DeclSyntax]) -> MemberBlockSyntax {
    let memberItems = syntaxs.map { decl -> MemberBlockItemSyntax in
        return MemberBlockItemSyntax(decl: decl)
    }

    return MemberBlockSyntax(
        leftBrace: .leftBraceToken(),
        members: MemberBlockItemListSyntax(memberItems),
        rightBrace: .rightBraceToken()
    )
}

func buildInheritanceList(_ inheritance: [String]) -> InheritanceClauseSyntax {
    InheritanceClauseSyntax(
        colon: .colonToken(trailingTrivia: .space),
        inheritedTypes: InheritedTypeListSyntax(inheritance.enumerated().map { (offset, element) in
            InheritedTypeSyntax(
                type: TypeSyntax(IdentifierTypeSyntax(name: .identifier(element))),
                trailingComma: offset == inheritance.count - 1 ? nil : .commaToken(trailingTrivia: .space)
            )
        })
    )
}

func buildModifiers(_ keywords: [Keyword]) -> DeclModifierListSyntax {
    let mods = keywords.map { keyword in
        DeclModifierSyntax(
            name: .keyword(keyword, trailingTrivia: .space),
            detail: nil
        )
    }
    return DeclModifierListSyntax(mods)
}
