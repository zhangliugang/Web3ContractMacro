import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import Web3ContractMacroImpl

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(Web3ContractMacroImpl)
import Web3ContractMacroImpl

let testMacros: [String: Macro.Type] = [
    "Web3Contract": Web3ContractMacro.self,
]
#endif

final class Web3ContractMacroTests: XCTestCase {
    func testExtractStructNameIfAvailable() {
        let s1 = extractStructNameIfAvailable(internalType: "struct IStaking.CompositeVoteBucket[]")
        XCTAssertEqual(s1?.identifier, "CompositeVoteBucket")
        XCTAssertEqual(s1?.namespace, "IStaking")

        let s2 = extractStructNameIfAvailable(internalType: "struct IStaking.Candidate")
        XCTAssertEqual(s2?.identifier, "Candidate")
        XCTAssertEqual(s2?.namespace, "IStaking")

        let s3 = extractStructNameIfAvailable(internalType: "struct Candidate")
        XCTAssertEqual(s3?.identifier, "Candidate")
        XCTAssertNil(s3?.namespace)
    }

    func testSingleReturn() throws {
        let abi = "[{\"constant\":true,\"inputs\":[],\"name\":\"name\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"type\":\"function\"}]"
        #if canImport(Web3ContractMacroImpl)
        assertMacroExpansion(
            """
            @Web3Contract(#"\(abi)"#)
            class Contract {
            }
            """,
            expandedSource: """
            class Contract {

                \(reusePart(abi))

                func name() async throws -> String {
                    let method = contract.methods["name()"]!.first!
                    let data = method.encodeParameters([])
                    let transaction = CodableTransaction(to: contractAddress, data: data!)
                    let returnData = try await web3.eth.callTransaction(transaction)
                    let result = try method.decodeReturnData(returnData)
                    return result["0"] as! String
                }
            }
            """,
            macros: testMacros, indentationWidth: .spaces(4)
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testWithParams() throws {
        let abi = #"[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"payable":false,"type":"function"}]"#
        let abi2 = "[{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"},{\"name\":\"_spender\",\"type\":\"address\"}],\"name\":\"allowance\",\"outputs\":[{\"name\":\"remaining\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"}]"
        #if canImport(Web3ContractMacroImpl)
        assertMacroExpansion(
            """
            @Web3Contract(#"\(abi)"#)
            class Contract {
            }
            """,
            expandedSource: """
            class Contract {

                \(reusePart(abi))

                func balanceOf(_owner: EthereumAddress) async throws -> BigUInt {
                    let method = contract.methods["balanceOf(address)"]!.first!
                    let data = method.encodeParameters([_owner])
                    let transaction = CodableTransaction(to: contractAddress, data: data!)
                    let returnData = try await web3.eth.callTransaction(transaction)
                    let result = try method.decodeReturnData(returnData)
                    return result["0"] as! BigUInt
                }
            }
            """,
            macros: testMacros, indentationWidth: .spaces(4)
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif

        #if canImport(Web3ContractMacroImpl)
        assertMacroExpansion(
            """
            @Web3Contract(#"\(abi2)"#)
            class Contract {
            }
            """,
            expandedSource: """
            class Contract {

                \(reusePart(abi2))

                func allowance(_owner: EthereumAddress, _spender: EthereumAddress) async throws -> BigUInt {
                    let method = contract.methods["allowance(address,address)"]!.first!
                    let data = method.encodeParameters([_owner, _spender])
                    let transaction = CodableTransaction(to: contractAddress, data: data!)
                    let returnData = try await web3.eth.callTransaction(transaction)
                    let result = try method.decodeReturnData(returnData)
                    return result["0"] as! BigUInt
                }
            }
            """,
            macros: testMacros, indentationWidth: .spaces(4)
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testEventAndError() throws {
        let abi = "[{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"_from\",\"type\":\"address\"},{\"indexed\":true,\"name\":\"_to\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"Transfer\",\"type\":\"event\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"receiver\",\"type\":\"address\"}],\"name\":\"ERC1155InvalidReceiver\",\"type\":\"error\"}]"
        #if canImport(Web3ContractMacroImpl)
        assertMacroExpansion(
            """
            @Web3Contract(#"\(abi)"#)
            class Contract {
            }
            """,
            expandedSource: """
            class Contract {

                \(reusePart(abi))

                struct Transfer {
                    let _from: EthereumAddress
                    let _to: EthereumAddress
                    let _value: BigUInt
                }

                struct ERC1155InvalidReceiver: Error {
                    let receiver: EthereumAddress
                }
            }
            """,
            macros: testMacros, indentationWidth: .spaces(4)
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMultiOutput() throws {
        let abi = #"[{"inputs":[{"internalType":"uint256","name":"_tokenId","type":"uint256"}],"name":"bucketOf","outputs":[{"internalType":"uint256","name":"amount_","type":"uint256"},{"internalType":"uint256","name":"duration_","type":"uint256"},{"internalType":"uint256","name":"unlockedAt_","type":"uint256"},{"internalType":"uint256","name":"unstakedAt_","type":"uint256"},{"internalType":"address","name":"delegate_","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"a","type":"uint256"},{"internalType":"uint256","name":"b","type":"uint256"}],"name":"tryAdd","outputs":[{"internalType":"bool","name":"","type":"bool"},{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"pure","type":"function"},{"inputs":[{"internalType":"uint256","name":"a","type":"uint256"},{"internalType":"uint256","name":"b","type":"uint256"}],"name":"trySub","outputs":[{"internalType":"bool","name":"success","type":"bool"},{"internalType":"uint256","name":"result","type":"uint256"}],"stateMutability":"pure","type":"function"}]"#

        #if canImport(Web3ContractMacroImpl)
        assertMacroExpansion(
            """
            @Web3Contract(#"\(abi)"#)
            class Contract {
            }
            """,
            expandedSource: """
            class Contract {

                \(reusePart(abi))

                func bucketOf(_tokenId: BigUInt) async throws -> [String: Any] {
                    let method = contract.methods["bucketOf(uint256)"]!.first!
                    let data = method.encodeParameters([_tokenId])
                    let transaction = CodableTransaction(to: contractAddress, data: data!)
                    let returnData = try await web3.eth.callTransaction(transaction)
                    let result = try method.decodeReturnData(returnData)
                    return result as! [String: Any]
                }

                func tryAdd(a: BigUInt, b: BigUInt) async throws -> (Bool, BigUInt) {
                    let method = contract.methods["tryAdd(uint256,uint256)"]!.first!
                    let data = method.encodeParameters([a, b])
                    let transaction = CodableTransaction(to: contractAddress, data: data!)
                    let returnData = try await web3.eth.callTransaction(transaction)
                    let result = try method.decodeReturnData(returnData)
                    return (result["0"] as! Bool, result["1"] as! BigUInt)
                }

                func trySub(a: BigUInt, b: BigUInt) async throws -> (success: Bool, result: BigUInt) {
                    let method = contract.methods["trySub(uint256,uint256)"]!.first!
                    let data = method.encodeParameters([a, b])
                    let transaction = CodableTransaction(to: contractAddress, data: data!)
                    let returnData = try await web3.eth.callTransaction(transaction)
                    let result = try method.decodeReturnData(returnData)
                    return (result["0"] as! Bool, result["1"] as! BigUInt)
                }
            }
            """,
            macros: testMacros, indentationWidth: .spaces(4)
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}

func reusePart(_ abi: String) -> String {
    """
    private let abiString = \"""
            \(abi)
        \"""

        private let contract: EthereumContract
        private let contractAddress: EthereumAddress
        private var web3: Web3

        init(address: EthereumAddress, web3: Web3) {
            self.contractAddress = address
            self.web3 = web3
            self.contract = try! EthereumContract(abiString)
        }
    """
}
