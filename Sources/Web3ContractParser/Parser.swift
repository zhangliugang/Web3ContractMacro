//
//  Parser.swift
//  Web3ContractMacro
//
//  Created by liugang zhang on 2025/8/10.
//

import Foundation
import SwiftSyntax

public func parseAbiString(_ string: String, accessLevel: String = "internal") throws -> [DeclSyntax] {
    guard let keyword = switch accessLevel {
    case "public": Keyword.public
    case "private": Keyword.private
    case "internal": Keyword.internal
    case "package": Keyword.package
    default: nil
    } else {
        return []
    }

    let modifierList = buildModifiers([keyword])

    let jsonData = string.data(using: .utf8)
    let records = try JSONDecoder().decode([ABI.Record].self, from: jsonData!)
    let abiElements = try records.map({ record -> ABI.Element in
        return try record.parse()
    })

    let constants: [DeclSyntax] = [
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

    let errors = abiElements.compactMap { element in
        if case let .error(err) = element {
            return generateErrorSyntax(err, modifier: modifierList)
        }
        return nil
    }

    let events = abiElements.compactMap { element in
        if case let .event(err) = element {
            return generateEventSyntax(err, modifier: modifierList)
        }
        return nil
    }

    let internalTypes = generateFunctionInternalTypes(abiElements.compactMap({ element in
        if case let .function(fn) = element {
            return fn
        }
        return nil
    }), modifier: modifierList)

    let fns = abiElements.compactMap { element in
        if case let .function(fn) = element {
            return generateFunction(fn, modifier: modifierList)
        }
        return nil
    }

    return constants + internalTypes + events + errors + fns
}
