//
//  main.swift
//  Web3ContractMacro
//
//  Created by liugang zhang on 2025/8/8.
//

import ArgumentParser
import Foundation
import SwiftSyntax
import Web3ContractParser

@main
struct Generator: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "Gen swift code from contract abi")

    @Argument(help: "Input path(s): one or more JSON files or a directory containing JSON files.")
    var inputs: [String]

    @Option(
        name: [.short, .customLong("output")],
        help: "Optional output path. If a directory, output multiple files; if a file, merge output into it; if not specified, print to stdout."
    )
    var outputPath: String?

    mutating func run() throws {
        let inputFiles = try resolveInputFiles(from: inputs)

        let generatedFiles: [(filename: String, content: String)] = try inputFiles.map { path in
            let basename = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            let code = try generateSwiftCode(from: path)
            return ("\(basename).swift", code)
        }
        try writeOutput(generatedFiles)
    }

    func resolveInputFiles(from paths: [String]) throws -> [String] {
        var files: [String] = []

        for path in paths {
            let url = URL(fileURLWithPath: path)
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDir {
                let jsonFiles = try FileManager.default.contentsOfDirectory(atPath: path)
                    .filter { $0.hasSuffix(".json") }
                    .map { "\(path)/\($0)" }
                files.append(contentsOf: jsonFiles)
            } else if path.hasSuffix(".json") {
                files.append(path)
            }
        }

        return files
    }

    func generateSwiftCode(from jsonPath: String) throws -> String {
        let basename = URL(fileURLWithPath: jsonPath).deletingPathExtension().lastPathComponent.split(separator: ".").first!
        let clsName = basename[basename.startIndex].uppercased() + basename[basename.index(after: basename.startIndex)..<basename.endIndex]

        let json = try String(contentsOfFile: jsonPath)

        let syntaxs = try parseAbiString(json)
        let codeBlocks = syntaxs.map { decl in
            MemberBlockItemSyntax(decl: (decl))
        }
        let clsSyntax = ClassDeclSyntax(
            name: .identifier(clsName),
            memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax(codeBlocks))
        ).as(DeclSyntax.self)!

        let sourceFile = SourceFileSyntax(
            statements: CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: .decl("import web3swift")),
                CodeBlockItemSyntax(item: .decl("import Web3Core")).with(\.trailingTrivia, .newlines(2)),
                CodeBlockItemSyntax(item: .decl(clsSyntax))
            ]),
            endOfFileToken: .endOfFileToken()
        )

        return sourceFile.formatted().description
    }

    func writeOutput(_ files: [(filename: String, content: String)]) throws {
        if let outputPath {
            let url = URL(fileURLWithPath: outputPath)
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if !isDir {
                // Merge all into one file
                let merged = files.map { $0.content }.joined(separator: "\n\n")
                try merged.write(toFile: outputPath, atomically: true, encoding: .utf8)
            } else {
                // Ensure directory exists
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

                for file in files {
                    let filePath = url.appendingPathComponent(file.filename).path
                    try file.content.write(toFile: filePath, atomically: true, encoding: .utf8)
                }
            }
        } else {
            // Print to stdout
            for file in files {
                print("// ===== \(file.filename) =====")
                print(file.content)
                print()
            }
        }
    }
}
