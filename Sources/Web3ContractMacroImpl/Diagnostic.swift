//
//  File.swift
//  
//
//  Created by liugang zhang on 2023/11/20.
//

import SwiftDiagnostics

enum Diagnostic: DiagnosticMessage {
    case invalidJson(String)

    var message: String {
        switch self {
        case .invalidJson(let str):
            str
        }
    }

    var diagnosticID: MessageID {
        switch self {
        case .invalidJson(let str):
            .init(domain: "invalidJson", id: str)
        }

    }

    var severity: DiagnosticSeverity {
        .error
    }

}
