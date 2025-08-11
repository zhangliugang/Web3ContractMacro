//
//  CodeGenPlugin.swift
//  Web3ContractMacro
//
//  Created by liugang zhang on 2025/8/8.
//

import Foundation
import PackagePlugin
import XcodeProjectPlugin

@main
struct CodeGenPlugin: BuildToolPlugin, XcodeBuildToolPlugin {
    func performCommand(context: XcodeProjectPlugin.XcodePluginContext, arguments: [String]) throws {

    }

    func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
        [
            .buildCommand(displayName: "GEN", executable: try context.tool(named: "").path, arguments: [])
        ]
    }
    
    func createBuildCommands(context: PackagePlugin.PluginContext, target: any PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
        [
            .buildCommand(displayName: "GEN", executable: try context.tool(named: "").path, arguments: [])
        ]
    }
    

}
