
@attached(member, names: arbitrary)
public macro Web3Contract(_ abi: StaticString) = #externalMacro(module: "Web3ContractMacroImpl", type: "Web3ContractMacro")
