// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Web3ContractMacro",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "Web3ContractMacro",
            targets: ["Web3ContractMacro"]
        ),
        .executable(name: "Web3ContractCodeGen", targets: ["Web3ContractCodeGen"]),
        .plugin(name: "CodeGenCommand", targets: ["CodeGenCommand"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .macro(
            name: "Web3ContractMacroImpl",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .target(name: "Web3ContractParser")
            ]
        ),
        .target(name: "Web3ContractMacro", dependencies: ["Web3ContractMacroImpl"]),
        .target(name: "Demo", dependencies: ["Web3ContractMacro"]),
        .target(name: "Web3ContractParser", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        ]),
        .executableTarget(name: "Web3ContractCodeGen", dependencies: [.target(name: "Web3ContractParser")]),
        .testTarget(
            name: "Web3ContractMacroTests",
            dependencies: [
                "Web3ContractMacroImpl",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .plugin(
            name: "CodeGenCommand",
            capability: .command(
                intent: .custom(
                    verb: "GenerateContractCode",
                    description: "GenerateContractCode"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Modifies Xcode project to fix package reference for plugins")
                ]
            ),
            dependencies: ["Web3ContractCodeGen"]
        )
    ]
)
