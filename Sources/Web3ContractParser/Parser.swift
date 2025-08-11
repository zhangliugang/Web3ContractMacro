//
//  Parser.swift
//  Web3ContractMacro
//
//  Created by liugang zhang on 2025/8/10.
//

import Foundation
import SwiftSyntax

public func parseAbiString(_ string: String) throws -> [DeclSyntax] {
    let jsonData = string.data(using: .utf8)
    let records = try JSONDecoder().decode([ABI.Record].self, from: jsonData!)
    let abiElements = try records.map({ record -> ABI.Element in
        return try record.parse()
    })

    let errors = abiElements.compactMap { element in
        if case let .error(err) = element {
            return generateErrorSyntax(err)
        }
        return nil
    }

    let events = abiElements.compactMap { element in
        if case let .event(err) = element {
            return generateEventSyntax(err)
        }
        return nil
    }

    let internalTypes = generateFunctionInternalTypes(abiElements.compactMap({ element in
        if case let .function(fn) = element {
            return fn
        }
        return nil
    }))

    let fns = abiElements.compactMap { element in
        if case let .function(fn) = element {
            return generateFunction(fn)
        }
        return nil
    }

    return internalTypes + events + errors + fns
}

