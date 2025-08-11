//
//  File.swift
//  
//
//  Created by liugang zhang on 2023/11/18.
//

import Foundation

extension String {
    func trim() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var fullNSRange: NSRange {
        return NSRange(startIndex..<endIndex, in: self)
    }
}

struct ABI {
    struct Input: Decodable {
        public var name: String?
        public var type: String
        public var indexed: Bool?
        public var components: [Input]?
    }

    struct Output: Decodable {
        public var name: String?
        public var type: String
        public var components: [Output]?
        public var internalType: String?
    }

    struct Record: Decodable {
        public var name: String?
        public var type: String?
        public var payable: Bool?
        public var constant: Bool?
        public var stateMutability: String?
        public var inputs: [ABI.Input]?
        public var outputs: [ABI.Output]?
        public var anonymous: Bool?
    }

    enum Element {
        public enum ArraySize { // bytes for convenience
            case staticSize(UInt64)
            case dynamicSize
            case notArray
        }

        case function(Function)
        case constructor(Constructor)
        case fallback(Fallback)
        case event(Event)
        case receive(Receive)
        case error(EthError)

        public enum StateMutability {
            case payable
            case mutating
            case view
            case pure

            var isConstant: Bool {
                switch self {
                case .payable:
                    return false
                case .mutating:
                    return false
                default:
                    return true
                }
            }

            var isPayable: Bool {
                switch self {
                case .payable:
                    return true
                default:
                    return false
                }
            }
        }

        public struct InOut {
            public let name: String
            public let type: ParameterType

            public init(name: String, type: ParameterType) {
                self.name = name.trim()
                self.type = type
            }
        }

        public struct Function {
            public let name: String?
            public let inputs: [InOut]
            public let outputs: [InOut]
            public let stateMutability: StateMutability? = nil
            public let constant: Bool
            public let payable: Bool

            public init(name: String?, inputs: [InOut], outputs: [InOut], constant: Bool, payable: Bool) {
                self.name = name?.trim()
                self.inputs = inputs
                self.outputs = outputs
                self.constant = constant
                self.payable = payable
            }
        }

        public struct Constructor {
            public let inputs: [InOut]
            public let constant: Bool
            public let payable: Bool

            public init(inputs: [InOut], constant: Bool, payable: Bool) {
                self.inputs = inputs
                self.constant = constant
                self.payable = payable
            }
        }

        public struct Fallback {
            public let constant: Bool
            public let payable: Bool

            public init(constant: Bool, payable: Bool) {
                self.constant = constant
                self.payable = payable
            }
        }

        public struct Event {
            public let name: String
            public let inputs: [Input]
            public let anonymous: Bool

            public init(name: String, inputs: [Input], anonymous: Bool) {
                self.name = name.trim()
                self.inputs = inputs
                self.anonymous = anonymous
            }

            public struct Input {
                public let name: String
                public let type: ParameterType
                public let indexed: Bool

                public init(name: String, type: ParameterType, indexed: Bool) {
                    self.name = name.trim()
                    self.type = type
                    self.indexed = indexed
                }
            }
        }
        public struct Receive {
            public let payable: Bool
            public let inputs: [InOut]

            public init(inputs: [InOut], payable: Bool) {
                self.inputs = inputs
                self.payable = payable
            }
        }
        /// Custom structured error type available since solidity 0.8.4
        public struct EthError {
            public let name: String
            public let inputs: [InOut]

            // e.g. `CustomError(uint32, address sender)`
            public var errorDeclaration: String {
                "\(name)(\(inputs.map { "\($0.type.abiRepresentation) \($0.name)".trim() }.joined(separator: ",")))"
            }

            public init(name: String, inputs: [InOut] = []) {
                self.name = name.trim()
                self.inputs = inputs
            }
        }

        public struct Structs {
            public let name: String
            public let inputs: [InOut]

            public init(name: String, inputs: [InOut]) {
                self.name = name.trim()
                self.inputs = inputs
            }
        }
    }
}

protocol ABIElementPropertiesProtocol {
    var isStatic: Bool {get}
    var isArray: Bool {get}
    var isTuple: Bool {get}
    var arraySize: ABI.Element.ArraySize {get}
    var subtype: ABI.Element.ParameterType? {get}
    var memoryUsage: UInt64 {get}
//    var emptyValue: Any {get}
}

extension ABI.Element {
    
    /// Specifies the type that parameters in a contract have.
    public enum ParameterType: ABIElementPropertiesProtocol {
        case uint(bits: UInt64)
        case int(bits: UInt64)
        case address
        case function
        case bool
        case bytes(length: UInt64)
        indirect case array(type: ParameterType, length: UInt64)
        case dynamicBytes
        case string
        indirect case tuple(types: [InOut], structName: ABI.StructName?)

        var isStatic: Bool {
            switch self {
            case .string:
                return false
            case .dynamicBytes:
                return false
            case .array(type: let type, length: let length):
                if length == 0 {
                    return false
                }
                if !type.isStatic {
                    return false
                }
                return true
            case .tuple(types: let types, _):
                for t in types {
                    if !t.type.isStatic {
                        return false
                    }
                }
                return true
            case .bytes(length: _):
                return true
            default:
                return true
            }
        }

        var isArray: Bool {
            switch self {
            case .array(type: _, length: _):
                return true
            default:
                return false
            }
        }

        var isTuple: Bool {
            switch self {
            case .tuple:
                return true
            default:
                return false
            }
        }

        var subtype: ABI.Element.ParameterType? {
            switch self {
            case .array(type: let type, length: _):
                return type
            default:
                return nil
            }
        }

        var memoryUsage: UInt64 {
            switch self {
            case .array(_, length: let length):
                if length == 0 {
                    return 32
                }
                if self.isStatic {
                    return 32*length
                }
                return 32
            case .tuple(types: let types, _):
                if !self.isStatic {
                    return 32
                }
                var sum: UInt64 = 0
                for t in types {
                    sum = sum + t.type.memoryUsage
                }
                return sum
            default:
                return 32
            }
        }

        var typeName: String {
            switch self {
            case .uint:
                "BigUInt"
            case .int:
                "BigInt"
            case .address:
                "EthereumAddress"
            case .function:
                ""
            case .bool:
                "Bool"
            case .bytes:
                "Data"
            case .array(let type, _):
                "[\(type.typeName)]"
            case .dynamicBytes:
                "Data"
            case .string:
                "String"
            case .tuple(let types, _):
                "(" + types.map(\.type).map(\.typeName).joined(separator: ", ") + ")"
            }
        }

        var abiRepresentation: String {
            switch self {
            case .uint(let bits):
                return "uint\(bits)"
            case .int(let bits):
                return "int\(bits)"
            case .address:
                return "address"
            case .bool:
                return "bool"
            case .bytes(let length):
                return "bytes\(length)"
            case .dynamicBytes:
                return "bytes"
            case .function:
                return "function"
            case .array(type: let type, length: let length):
                if length == 0 {
                    return  "\(type.abiRepresentation)[]"
                }
                return "\(type.abiRepresentation)[\(length)]"
            case .tuple(types: let types, _):
                let typesRepresentation = types.map(\.type).map(\.abiRepresentation)
                let typesJoined = typesRepresentation.joined(separator: ",")
                return "(\(typesJoined))"
            case .string:
                return "string"
            }
        }

        var arraySize: ABI.Element.ArraySize {
            switch self {
            case .array(type: _, length: let length):
                if length == 0 {
                    return ArraySize.dynamicSize
                }
                return ArraySize.staticSize(length)
            default:
                return ArraySize.notArray
            }
        }
    }
}

extension ABI {
    public enum ParsingError: Swift.Error {
        case invalidJsonFile
        case elementTypeInvalid
        case elementNameInvalid
        case functionInputInvalid
        case functionOutputInvalid
        case eventInputInvalid
        case parameterTypeInvalid
        case parameterTypeNotFound
        case abiInvalid
    }

    enum TypeParsingExpressions {
        static var typeEatingRegex = "^((u?int|bytes)([1-9][0-9]*)|(address|bool|string|tuple|bytes)|(\\[([1-9][0-9]*)\\]))"
        static var arrayEatingRegex = "^(\\[([1-9][0-9]*)?\\])?.*$"
    }

    fileprivate enum ElementType: String {
        case function
        case constructor
        case fallback
        case event
        case receive
        case error
    }

    struct StructName: Hashable {
        let identifier: String
        let namespace: String?

        func hash(into hasher: inout Hasher) {
            identifier.hash(into: &hasher)
        }
    }
}

extension ABI.Record {
    public func parse() throws -> ABI.Element {
        let typeString = self.type ?? "function"
        guard let type = ABI.ElementType(rawValue: typeString) else {
            throw ABI.ParsingError.elementTypeInvalid
        }
        return try parseToElement(from: self, type: type)
    }
}

func extractStructNameIfAvailable(internalType: String?) -> ABI.StructName? {
    if let internalType = internalType, internalType.hasPrefix("struct ") {
        let typeArray = Array(internalType)
        var nameStr = String(typeArray[7...])
        let regex = try! NSRegularExpression(pattern: #"((?:\[\d*\])+)$"#)
        let match = regex.matches(in: nameStr, range: nameStr.fullNSRange)
        if !match.isEmpty {
            nameStr = String(Array(nameStr)[0..<nameStr.count - match.first!.range.length])
        }
        if nameStr.firstIndex(of: ".") != nil {
            let split = nameStr.split(separator: ".")
            return .init(identifier: String(split[1]), namespace: String(split[0]))
        }
        return .init(identifier: String(nameStr), namespace: nil)
    }
    return nil
}

//func parse(rawType: String, components: [ABI.Output]?, internalType: String?) {
//    let rawTypeArray = Array(rawType)
//    if let lastChar = rawTypeArray.last, lastChar == "]" {
//        var finishArrayTypeIndex = rawType.count - 2
//        while rawTypeArray[finishArrayTypeIndex] != "[" {
//            finishArrayTypeIndex -= 1
//        }
//        let arraySizeRaw = rawTypeArray[finishArrayTypeIndex + 1..<rawTypeArray.count - 1]
//        let arraySize: Int? = arraySizeRaw.isEmpty ? Int(String(arraySizeRaw)) : nil
//        let restOfType = String(rawTypeArray[0..<finishArrayTypeIndex])
//    }
//}

private func parseToElement(from abiRecord: ABI.Record, type: ABI.ElementType) throws -> ABI.Element {
    switch type {
    case .function:
        let function = try parseFunction(abiRecord: abiRecord)
        return ABI.Element.function(function)
    case .constructor:
        let constructor = try parseConstructor(abiRecord: abiRecord)
        return ABI.Element.constructor(constructor)
    case .fallback:
        let fallback = try parseFallback(abiRecord: abiRecord)
        return ABI.Element.fallback(fallback)
    case .event:
        let event = try parseEvent(abiRecord: abiRecord)
        return ABI.Element.event(event)
    case .receive:
        let receive = try parseReceive(abiRecord: abiRecord)
        return ABI.Element.receive(receive)
    case .error:
        let error = try parseError(abiRecord: abiRecord)
        return ABI.Element.error(error)
    }

}

private func parseFunction(abiRecord: ABI.Record) throws -> ABI.Element.Function {
    let inputs = try abiRecord.inputs?.map({ (input: ABI.Input) throws -> ABI.Element.InOut in
        let nativeInput = try input.parse()
        return nativeInput
    })
    let abiInputs = inputs ?? [ABI.Element.InOut]()
    let outputs = try abiRecord.outputs?.map({ (output: ABI.Output) throws -> ABI.Element.InOut in
        let nativeOutput = try output.parse()
        return nativeOutput
    })
    let abiOutputs = outputs ?? [ABI.Element.InOut]()
    let name = abiRecord.name ?? ""
    let payable = abiRecord.stateMutability == "payable" || abiRecord.payable == true
    let constant = abiRecord.constant == true || abiRecord.stateMutability == "view" || abiRecord.stateMutability == "pure"
    let functionElement = ABI.Element.Function(name: name, inputs: abiInputs, outputs: abiOutputs, constant: constant, payable: payable)
    return functionElement
}

private func parseFallback(abiRecord: ABI.Record) throws -> ABI.Element.Fallback {
    let payable = (abiRecord.stateMutability == "payable" || abiRecord.payable == true)
    let constant = abiRecord.constant == true || abiRecord.stateMutability == "view" || abiRecord.stateMutability == "pure"
    let functionElement = ABI.Element.Fallback(constant: constant, payable: payable)
    return functionElement
}

private func parseConstructor(abiRecord: ABI.Record) throws -> ABI.Element.Constructor {
    let inputs = try abiRecord.inputs?.map({ (input: ABI.Input) throws -> ABI.Element.InOut in
        let nativeInput = try input.parse()
        return nativeInput
    })
    let abiInputs = inputs ?? [ABI.Element.InOut]()
    let payable = abiRecord.stateMutability == "payable" || abiRecord.payable == true
    let functionElement = ABI.Element.Constructor(inputs: abiInputs, constant: false, payable: payable)
    return functionElement
}

private func parseEvent(abiRecord: ABI.Record) throws -> ABI.Element.Event {
    let inputs = try abiRecord.inputs?.map({ (input: ABI.Input) throws -> ABI.Element.Event.Input in
        let nativeInput = try input.parseForEvent()
        return nativeInput
    })
    let abiInputs = inputs ?? [ABI.Element.Event.Input]()
    let name = abiRecord.name ?? ""
    let anonymous = abiRecord.anonymous ?? false
    let functionElement = ABI.Element.Event(name: name, inputs: abiInputs, anonymous: anonymous)
    return functionElement
}

private func parseReceive(abiRecord: ABI.Record) throws -> ABI.Element.Receive {
    let inputs = try abiRecord.inputs?.map({ (input: ABI.Input) throws -> ABI.Element.InOut in
        let nativeInput = try input.parse()
        return nativeInput
    })
    let abiInputs = inputs ?? [ABI.Element.InOut]()
    let payable = abiRecord.stateMutability == "payable" || abiRecord.payable == true
    let functionElement = ABI.Element.Receive(inputs: abiInputs, payable: payable)
    return functionElement
}

private func parseError(abiRecord: ABI.Record) throws -> ABI.Element.EthError {
    let abiInputs = try abiRecord.inputs?.map({ input throws -> ABI.Element.InOut in
        try input.parse()
    }) ?? []
    let name = abiRecord.name ?? ""
    return ABI.Element.EthError(name: name, inputs: abiInputs)
}

extension ABI.Input {
    func parse() throws -> ABI.Element.InOut {
        let name = self.name ?? ""
        let parameterType = try ABITypeParser.parseTypeString(self.type)
        if case .tuple(types: _) = parameterType {
            let components = try self.components?.compactMap({ (inp: ABI.Input) throws -> ABI.Element.InOut in
                let input = try inp.parse()
                return .init(name: input.name, type: input.type)
            })
            let type = ABI.Element.ParameterType.tuple(types: components!, structName: nil)
            let nativeInput = ABI.Element.InOut(name: name, type: type)
            return nativeInput
        } else if case .array(type: .tuple(types: _), length: _) = parameterType {
            let components = try self.components?.compactMap({ (inp: ABI.Input) throws -> ABI.Element.InOut in
                let input = try inp.parse()
                return .init(name: input.name, type: input.type)
            })
            let tupleType = ABI.Element.ParameterType.tuple(types: components!, structName: nil)

            let newType: ABI.Element.ParameterType = .array(type: tupleType, length: 0)
            let nativeInput = ABI.Element.InOut(name: name, type: newType)
            return nativeInput
        } else {
            let nativeInput = ABI.Element.InOut(name: name, type: parameterType)
            return nativeInput
        }
    }

    func parseForEvent() throws -> ABI.Element.Event.Input {
        let name = self.name ?? ""
        let parameterType = try ABITypeParser.parseTypeString(self.type)
        let indexed = self.indexed == true
        return ABI.Element.Event.Input(name: name, type: parameterType, indexed: indexed)
    }
}

extension ABI.Output {
    func parse() throws -> ABI.Element.InOut {
        let name = self.name != nil ? self.name! : ""
        let parameterType = try ABITypeParser.parseTypeString(self.type)
        switch parameterType {
        case .tuple(types: _):
            let components = try self.components?.compactMap({ (inp: ABI.Output) throws -> ABI.Element.InOut in
                let input = try inp.parse()
                return .init(name: input.name, type: input.type)
            })
            let internalStruct = extractStructNameIfAvailable(internalType: internalType)
            let type = ABI.Element.ParameterType.tuple(types: components!, structName: internalStruct)
            let nativeInput = ABI.Element.InOut(name: name, type: type)
            return nativeInput
        case .array(type: let subtype, length: let length):
            switch subtype {
            case .tuple(types: _):
                let components = try self.components?.compactMap({ (inp: ABI.Output) throws -> ABI.Element.InOut in
                    let input = try inp.parse()
                    return .init(name: input.name, type: input.type)
                })
                let internalStruct = extractStructNameIfAvailable(internalType: internalType)
                let nestedSubtype = ABI.Element.ParameterType.tuple(types: components!, structName: internalStruct)
                let properType = ABI.Element.ParameterType.array(type: nestedSubtype, length: length)
                let nativeInput = ABI.Element.InOut(name: name, type: properType)
                return nativeInput
            default:
                let nativeInput = ABI.Element.InOut(name: name, type: parameterType)
                return nativeInput
            }
        default:
            let nativeInput = ABI.Element.InOut(name: name, type: parameterType)
            return nativeInput
        }
    }
}


public struct ABITypeParser {

    private enum BaseParameterType: String {
        case address
        case uint
        case int
        case bool
        case function
        case bytes
        case string
        case tuple
    }

    static func baseTypeMatch(from string: String, length: UInt64 = 0) -> ABI.Element.ParameterType? {
        switch BaseParameterType(rawValue: string) {
        case .address?:
            return .address
        case .uint?:
            return .uint(bits: length == 0 ? 256: length)
        case .int?:
            return .int(bits: length == 0 ? 256: length)
        case .bool?:
            return .bool
        case .function?:
            return .function
        case .bytes?:
            if length == 0 {
                return .dynamicBytes
            }
            return .bytes(length: length)
        case .string?:
            return .string
        case .tuple?:
            return .tuple(types: [ABI.Element.InOut](), structName: nil)
        default:
            return nil
        }
    }

    static func parseTypeString(_ string: String) throws -> ABI.Element.ParameterType {
        let (type, tail) = recursiveParseType(string)
        guard let t = type, tail == nil else {throw ABI.ParsingError.elementTypeInvalid}
        return t
    }

    static func recursiveParseType(_ string: String) -> (type: ABI.Element.ParameterType?, tail: String?) {
        let matcher = try! NSRegularExpression(pattern: ABI.TypeParsingExpressions.typeEatingRegex, options: NSRegularExpression.Options.dotMatchesLineSeparators)
        let match = matcher.matches(in: string, options: NSRegularExpression.MatchingOptions.anchored, range: string.fullNSRange)
        guard match.count == 1 else {
            return (nil, nil)
        }
        var tail: String = ""
        var type: ABI.Element.ParameterType?
        guard match[0].numberOfRanges >= 1 else {return (nil, nil)}
        guard let baseTypeRange = Range(match[0].range(at: 1), in: string) else {return (nil, nil)}
        let baseTypeString = String(string[baseTypeRange])
        if match[0].numberOfRanges >= 2, let exactTypeRange = Range(match[0].range(at: 2), in: string) {
            let typeString = String(string[exactTypeRange])
            if match[0].numberOfRanges >= 3, let lengthRange = Range(match[0].range(at: 3), in: string) {
                let lengthString = String(string[lengthRange])
                guard let typeLength = UInt64(lengthString) else {return (nil, nil)}
                guard let baseType = baseTypeMatch(from: typeString, length: typeLength) else {return (nil, nil)}
                type = baseType
            } else {
                guard let baseType = baseTypeMatch(from: typeString, length: 0) else {return (nil, nil)}
                type = baseType
            }
        } else {
            guard let baseType = baseTypeMatch(from: baseTypeString, length: 0) else {return (nil, nil)}
            type = baseType
        }
        tail = string.replacingCharacters(in: string.range(of: baseTypeString)!, with: "")
        if tail == "" {
            return (type, nil)
        }
        return recursiveParseArray(baseType: type!, string: tail)
    }

    static func recursiveParseArray(baseType: ABI.Element.ParameterType, string: String) -> (type: ABI.Element.ParameterType?, tail: String?) {
        let matcher = try! NSRegularExpression(pattern: ABI.TypeParsingExpressions.arrayEatingRegex, options: NSRegularExpression.Options.dotMatchesLineSeparators)
        let match = matcher.matches(in: string, options: NSRegularExpression.MatchingOptions.anchored, range: string.fullNSRange)
        guard match.count == 1 else {return (nil, nil)}
        var tail: String = ""
        var type: ABI.Element.ParameterType?
        guard match[0].numberOfRanges >= 1 else {return (nil, nil)}
        guard let baseArrayRange = Range(match[0].range(at: 1), in: string) else {return (nil, nil)}
        let baseArrayString = String(string[baseArrayRange])
        if match[0].numberOfRanges >= 2, let exactArrayRange = Range(match[0].range(at: 2), in: string) {
            let lengthString = String(string[exactArrayRange])
            guard let arrayLength = UInt64(lengthString) else {return (nil, nil)}
            let baseType = ABI.Element.ParameterType.array(type: baseType, length: arrayLength)
            type = baseType
        } else {
            let baseType = ABI.Element.ParameterType.array(type: baseType, length: 0)
            type = baseType
        }
        tail = string.replacingCharacters(in: string.range(of: baseArrayString)!, with: "")
        if tail == "" {
            return (type, nil)
        }
        return recursiveParseArray(baseType: type!, string: tail)
    }
}
