import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct Web3ContractMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        Web3ContractMacro.self,
    ]
}
