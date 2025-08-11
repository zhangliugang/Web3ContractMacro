//
//  CodeGenCommand.swift
//  Web3ContractMacro
//
//  Created by liugang zhang on 2025/8/11.
//

import PackagePlugin
import Foundation

@main
struct CodeGenCommand: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let resourcesDirectoryPath = context.package.directory
        let inputDir = resourcesDirectoryPath.appending(subpath: "abis")
        let outDir = context.pluginWorkDirectory.appending(subpath: "generated")

        let toolPath = try context.tool(named: "Web3ContractCodeGen").path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath.string)
        process.arguments = [
            "\(inputDir)",
            "-o", "\(outDir)"
        ]

        try process.run()
        process.waitUntilExit()
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension CodeGenCommand: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        print(arguments)
        let resourcesDirectoryPath = context.xcodeProject.directory
        let inputDir = resourcesDirectoryPath.appending(subpath: "abis")
        let outDir = resourcesDirectoryPath.appending(subpath: "generated")

        try FileManager.default.createDirectory(atPath: outDir.string, withIntermediateDirectories: true)

        let tool = try context.tool(named: "Web3ContractCodeGen").path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool.string)
        process.arguments = [
            "\(inputDir)",
            "-o", "\(outDir)"
        ]

        try process.run()
        process.waitUntilExit()
    }
}
#endif
