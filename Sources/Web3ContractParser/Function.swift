//
//  Function.swift
//  Web3ContractMacro
//
//  Created by liugang zhang on 2025/8/10.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftParser

func generateFunctionInternalTypes(_ fns: [ABI.Element.Function]) -> [DeclSyntax] {
    let functionOutputs = fns.flatMap(\.outputs).map(\.type)
    let outputStructs = parseStructsFrom(functionOutputs)

    var namespaces = Set<String>()
    var internalTypes = Set<String>()

    outputStructs.forEach { key, value in
        if let namespace = key.namespace {
            namespaces.insert(namespace)
        } else {
            internalTypes.insert(key.identifier)
        }
    }

    let namespaceSyntax = namespaces.map { namespace in
        let structSyntsxs = outputStructs.filter({ $0.key.namespace == namespace }).map { key, value in
            generateInternalType(key.identifier, output: value)
        }

        let memberBlock = buildMemberList(structSyntsxs)
        return DeclSyntax(EnumDeclSyntax(
            leadingTrivia: .newline,
            name: .identifier(namespace),
            memberBlock: memberBlock,
            trailingTrivia: .newline
        ))
    }
    let internalTypesSyntax = internalTypes.flatMap { typename in
        return outputStructs.filter({ $0.key.namespace == nil && $0.key.identifier == typename }).map { key, value in
            generateInternalType(key.identifier, output: value)
        }
    }

    return namespaceSyntax + internalTypesSyntax
}

func parseStructsFrom(_ outs: [ABI.Element.ParameterType]) -> [ABI.StructName: [ABI.Element.InOut]] {
    var result = [ABI.StructName: [ABI.Element.InOut]]()
    outs.forEach { out in
        if case let .tuple(params, structName) = out {
            if let structName {
                result[structName] = params
            }
            result.merge(parseStructsFrom(params.map(\.type)), uniquingKeysWith: { a, b in a })
        }
        if case let .array(type, _) = out {
            result.merge(parseStructsFrom([type]), uniquingKeysWith: { a, b in a })
        }
    }
    return result
}

func generateInternalType(_ name: String, output: [ABI.Element.InOut]) -> DeclSyntax {
    let properties: [DeclSyntax] = output.map { input in
        "let \(raw: input.name): \(raw: input.type.typeName)"
    }
    let memberBlock = buildMemberList(properties)
    return DeclSyntax(
        StructDeclSyntax(
            leadingTrivia: Trivia.newline,
            name: .identifier(name),
            memberBlock: memberBlock,
            trailingTrivia: .newline
        )
    )
}

func generateFunction(_ fn: ABI.Element.Function) -> DeclSyntax? {
    guard let name = fn.name else { return nil }

    let parameters = fn.inputs.map { input in
        (input.name, input.type.typeName)
    }

    let returnSyntax = if fn.outputs.count == 1 {
        generateReturnSyntax(fn.outputs[0].type)
    } else {
        generateTupleSyntax(fn.outputs)
    }
    let paramList = FunctionParameterListSyntax(
        generateFunctionParams(fn)
    )

    let returnClause = ReturnClauseSyntax(
        arrow: .arrowToken(trailingTrivia: .space),
        type: returnSyntax
    )

    return DeclSyntax(FunctionDeclSyntax(
        leadingTrivia: .newline,
        funcKeyword: .keyword(.func, trailingTrivia: .space),
        name: .identifier(name),
        signature: FunctionSignatureSyntax(
            parameterClause: FunctionParameterClauseSyntax(
                leftParen: .leftParenToken(),
                parameters: paramList,
                rightParen: .rightParenToken()
            ),
            effectSpecifiers: FunctionEffectSpecifiersSyntax(asyncSpecifier: .keyword(.async), throwsSpecifier: .keyword(.throws)),
            returnClause: returnClause
        ),
        genericWhereClause: nil,
        body: generateFunctionBody(fn),
        trailingTrivia: .newline
    ))
}

func generateFunctionBody(_ fn: ABI.Element.Function) -> CodeBlockSyntax {
    let signature = "\(fn.name!)(\(fn.inputs.map { $0.type.abiRepresentation }.joined(separator: ",")))"
    let encodeParam = fn.inputs.map(\.name).joined(separator: ", ")

    let items: [CodeBlockItemSyntax] = [
        .init(item: .decl("let method = contract.methods[\"\(raw: signature)\"]!.first!")),
        .init(item: .decl("let data = method.encodeParameters([\(raw: encodeParam)])")),
        .init(item: .decl("let transaction = CodableTransaction(to: contractAddress, data: data!)")),
        .init(item: .decl("let returnData = try await web3.eth.callTransaction(transaction)")),
        .init(item: .decl("let result = try method.decodeReturnData(returnData)")),
    ] + generateReturnStmt(fn.outputs)
    return CodeBlockSyntax(
        leftBrace: .leftBraceToken(leadingTrivia: .space),
        statements: CodeBlockItemListSyntax(items),
        rightBrace: .rightBraceToken(leadingTrivia: .newline)
    )
}

func generateFunctionParams(_ fn: ABI.Element.Function) -> [FunctionParameterSyntax] {
    fn.inputs.enumerated().map { index, element in
        return FunctionParameterSyntax(
            firstName: TokenSyntax.identifier(element.name),
            type: IdentifierTypeSyntax(name: TokenSyntax.identifier(element.type.typeName)),
            trailingComma: index < fn.inputs.count - 1
                ? .commaToken(trailingTrivia: .space)
                : nil
        )
    }
}

func generateReturnSyntax(_ type: ABI.Element.ParameterType) -> TypeSyntaxProtocol {
    if case let .tuple(types, structName) = type {
        if let structName {
            if let namespace = structName.namespace {
                let typename = "\(namespace).\(structName.identifier)"
                return TypeSyntax(IdentifierTypeSyntax(name: .identifier(typename)))
            } else {
                return TypeSyntax(IdentifierTypeSyntax(name: .identifier(structName.identifier)))
            }
        } else {
            return generateTupleSyntax(types)
        }
    } else if case let .array(listType, _) = type {
        return ArrayTypeSyntax(element: generateReturnSyntax(listType))
    } else {
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier(type.typeName)))
    }
}

func generateTupleSyntax(_ outs: [ABI.Element.InOut], alias: Bool = true) -> TypeSyntaxProtocol {
    TupleTypeSyntax(
        leftParen: .leftParenToken(),
        elements: TupleTypeElementListSyntax(
            outs.enumerated().map { index, element in
                TupleTypeElementSyntax(
                    firstName: !element.name.isEmpty && alias && !element.name.first!.isNumber ? .identifier(element.name) : nil,
                    colon: !element.name.isEmpty && alias && !element.name.first!.isNumber ? .colonToken():  nil,
                    type: generateReturnSyntax(element.type),
                    trailingComma: index < outs.count - 1
                        ? .commaToken(trailingTrivia: .space)
                        : nil
                )
            }
        ),
        rightParen: .rightParenToken()
    )
}

func generateReturnStmt(_ outputs: [ABI.Element.InOut]) -> [CodeBlockItemSyntax] {
    let elements = generateTupleSyntax(outputs).as(TupleTypeSyntax.self)!.elements
    if elements.isEmpty {
        return []
    } else {
        var statements = [CodeBlockItemSyntax]()
        let tupleElements = outputs.enumerated().map { index, out in
            generateTypeCast(
                result: "result",
                statements: &statements,
                index: index,
                type: out.type,

            )
        }

        let returnExpr: ExprSyntax
        if tupleElements.count == 1 {
            returnExpr = tupleElements[0]
        } else {
            returnExpr = ExprSyntax(
                TupleExprSyntax {
                    for element in tupleElements {
                        LabeledExprSyntax(leadingTrivia: .newline, expression: element)

                    }
                }
                .with(\.rightParen, .rightParenToken(leadingTrivia: .newline))
            )
        }

        statements.append(CodeBlockItemSyntax(item: .init(
            ReturnStmtSyntax(
                leadingTrivia: .newline,
                expression: returnExpr
            )
        )))

        return statements
    }
}

func generateTypeCast(result: String, statements: inout [CodeBlockItemSyntax], index: Int, type: ABI.Element.ParameterType) -> ExprSyntax {
    let nestResult = "\(result)_\(index)"

    if case let .tuple(types, structName) = type {
        let dictAccess: ExprSyntax = "\(raw: result)[\(literal: index)] as! [String: Any]"
        statements.append(CodeBlockItemSyntax(item: .init(
            VariableDeclSyntax(bindingSpecifier: .keyword(.let)) {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(nestResult)),
                    initializer: InitializerClauseSyntax(value: dictAccess)
                )
            }
        )))

        if let structName {
            let typeExpr: ExprSyntax = if let namespace = structName.namespace {
                "\(raw: namespace).\(raw: structName.identifier)"
            } else {
                "\(raw: structName.identifier)"
            }

            return ExprSyntax(FunctionCallExprSyntax(
                calledExpression: typeExpr,
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax {
                    for (i, t) in types.enumerated() {
                        LabeledExprSyntax(
                            leadingTrivia: .newline,
                            label: .identifier(t.name),
                            colon: .colonToken(),
                            expression: generateTypeCast(
                                result: nestResult,
                                statements: &statements,
                                index: i,
                                type: t.type
                            )
                        )
                    }
                },
                rightParen: .rightParenToken(leadingTrivia: .newline)
            ))
        } else {
            return ExprSyntax(TupleExprSyntax {
                for (i, t) in types.enumerated() {
                    LabeledExprSyntax(
                        leadingTrivia: .newline,
                        expression: generateTypeCast(
                            result: nestResult,
                            statements: &statements,
                            index: i,
                            type: t.type,
                        ),
                        trailingTrivia: .newline
                    )
                }
            }.with(\.rightParen, .rightParenToken(leadingTrivia: .newline)))
        }
    } else if case let .array(listType, _) = type {
        return generateListTypeCast(result: result, statements: &statements, index: index, type: listType)
    } else {
        return "\(raw: result)[\(literal: index)] as! \(raw: type.typeName)"
    }
}

func generateListTypeCast(result: String, statements: inout [CodeBlockItemSyntax], index: Int, type: ABI.Element.ParameterType) -> ExprSyntax {
    let nestResult = "\(result)_\(index)"
    if case let .tuple(types, structName) = type {
        let arrayAccess: ExprSyntax = "\(raw: result)[\(literal: index)] as! [[String: Any]]"
        statements.append(CodeBlockItemSyntax(item: .init(
            VariableDeclSyntax(bindingSpecifier: .keyword(.let)) {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(nestResult)),
                    initializer: InitializerClauseSyntax(value: arrayAccess)
                )
            }
        )))

        if let structName {
            let typeExpr: ExprSyntax = if let namespace = structName.namespace {
                "\(raw: namespace).\(raw: structName.identifier)"
            } else {
                "\(raw: structName.identifier)"
            }

            return ExprSyntax(FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                    base: ExprSyntax("\(raw: nestResult)"),
                    name: .identifier("map")
                ),
                leftParen: .leftParenToken(),
                arguments: [
                    LabeledExprSyntax(
                        expression: ClosureExprSyntax(
                            leadingTrivia: .newline,
                            signature: .init(
                                parameterClause: .parameterClause(
                                    ClosureParameterClauseSyntax(
                                        leftParen: .leftParenToken(presence: .missing),
                                        parameters: [
                                            ClosureParameterSyntax(stringLiteral: "element")
                                        ],
                                        rightParen: .rightParenToken(presence: .missing)
                                    )
                                )
                            ),
                            statements: CodeBlockItemListSyntax {
                                ReturnStmtSyntax(
                                    expression: ExprSyntax(FunctionCallExprSyntax(
                                        calledExpression: typeExpr,
                                        leftParen: .leftParenToken(),
                                        arguments: LabeledExprListSyntax {
                                            for (i, t) in types.enumerated() {
                                                LabeledExprSyntax(
                                                    leadingTrivia: .newline,
                                                    label: .identifier(t.name),
                                                    colon: .colonToken(),
                                                    expression: generateTypeCast(
                                                        result: "element",
                                                        statements: &statements,
                                                        index: i,
                                                        type: t.type
                                                    )
                                                )
                                            }
                                        },
                                        rightParen: .rightParenToken(leadingTrivia: .newline)
                                    ))
                                )
                            }
                        )
                    )
                ],
                rightParen: .rightParenToken(leadingTrivia: .newline)
            ))
        } else {
            return ExprSyntax(FunctionCallExprSyntax(
                calledExpression: MemberAccessExprSyntax(
                    base: ExprSyntax("\(raw: nestResult)"),
                    name: .identifier("map")
                ),
                leftParen: .leftParenToken(),
                arguments: [
                    LabeledExprSyntax(
                        expression: ClosureExprSyntax(
                            leadingTrivia: .newline,
                            signature: .init(
                                parameterClause: .parameterClause(
                                    ClosureParameterClauseSyntax(
                                        leftParen: .leftParenToken(presence: .missing),
                                        parameters: [
                                            ClosureParameterSyntax(stringLiteral: "element")
                                        ],
                                        rightParen: .rightParenToken(presence: .missing)
                                    )
                                )
                            ),
                            statements: CodeBlockItemListSyntax {
                                ReturnStmtSyntax(
                                    expression: ExprSyntax(TupleExprSyntax {
                                        for (i, t) in types.enumerated() {
                                            LabeledExprSyntax(
                                                leadingTrivia: .newline,
                                                expression: generateTypeCast(
                                                    result: nestResult,
                                                    statements: &statements,
                                                    index: i,
                                                    type: t.type,
                                                ),
                                            )
                                        }
                                    }.with(\.rightParen, .rightParenToken(leadingTrivia: .newline)))
                                )
                            }
                        )
                    )
                ],
                rightParen: .rightParenToken(leadingTrivia: .newline)
            ))

        }
    } else if case let .array(listType, _) = type {
        let arrayAccess: ExprSyntax = "\(raw: result)[\(literal: index)] as! [Any]"
        statements.append(CodeBlockItemSyntax(item: .init(
            VariableDeclSyntax(bindingSpecifier: .keyword(.let)) {
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(nestResult)),
                    initializer: InitializerClauseSyntax(value: arrayAccess)
                )
            }
        )))

        return generateListTypeCast(result: nestResult, statements: &statements, index: index, type: listType)
    } else {
        return "\(raw: result)[\(literal: index)] as! [\(raw: type.typeName)]"
    }
}
