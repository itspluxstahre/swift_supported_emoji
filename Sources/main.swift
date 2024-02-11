import Foundation

struct SwiftCode: Codable {
    let emoji: String
    let label: String
}

import Foundation
import SwiftCLI

class ProcessCommand: Command {
    let name = "process"
    let shortDescription = "This command process the swift code"

    let jsonData = Key<String>("-j", "--json", description: "Path to JSON data file. Use the format lowerName=VALUE")
    let supportedFile = Key<String>("-s", "--supportedFile", description: "Path for supported swift file. Use the format upperName=VALUE")
    let unsupportedFile = Key<String>("-u", "--unsupportedFile", description: "Path for unsupported swift file. Use the format specialChar=VALUE")
    let overwrite = Flag("-o", "--overwrite", description: "Overwrite existing supported and unsupported swift files.")

    func execute() throws {
        var jsonDataPath = "data.raw.json"
        if let jsonPath = jsonData.value {
            jsonDataPath = jsonPath
        }

        var supportedFilePath = "supported.swift"
        if let supFile = supportedFile.value {
            supportedFilePath = supFile
        }

        var unsupportedFilePath = "unsupported.swift"
        if let unsupFile = unsupportedFile.value {
            unsupportedFilePath = unsupFile
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: supportedFileURL.path), !overwrite.value {
            print("Error: \(supportedFilePath) already exists. Use --overwrite to overwrite.")
            return
        }

        if fileManager.fileExists(atPath: unsupportedFileURL.path), !overwrite.value {
            print("Error: \(unsupportedFilePath) already exists. Use --overwrite to overwrite.")
            return
        }

        try main(jsonDataPath: jsonDataPath, supportedFilePath: supportedFilePath, unsupportedFilePath: unsupportedFilePath)
    }
}



func testSwiftCode(swiftCode: String) throws -> Bool {
    let tempDirectory = NSTemporaryDirectory()
    let tempFileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(UUID().uuidString).appendingPathExtension("swift")

    do {
        try swiftCode.write(to: tempFileURL, atomically: true, encoding: .utf8)
        
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [tempFileURL.path]
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)

        try FileManager.default.removeItem(at: tempFileURL)

        return output?.isEmpty ?? false
    } catch {
        print("An error occurred: \(error.localizedDescription)")
        throw error
    }
}


func main(jsonDataPath: String, supportedFilePath: String, unsupportedFilePath: String) throws {
    do {
        let fileManager = FileManager.default
        let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let jsonDataURL = currentDirectoryURL.appendingPathComponent(jsonDataPath)

        let supportedFileURL = currentDirectoryURL.appendingPathComponent(supportedFilePath)
        let unsupportedFileURL = currentDirectoryURL.appendingPathComponent(unsupportedFilePath)

        let data = try Data(contentsOf: jsonDataURL)
        let swiftCodes = try JSONDecoder().decode([SwiftCode].self, from: data)

        var supportedSwiftCode = ""
        var unsupportedSwiftCode = ""

        for item in swiftCodes {
            let swiftLine = "let \(item.emoji) = 1 /* \(item.label) */\n"

            if try testSwiftCode(swiftCode: swiftLine) {
                supportedSwiftCode += swiftLine
            } else {
                unsupportedSwiftCode += swiftLine
            }
        }

        try supportedSwiftCode.write(to: supportedFileURL, atomically: true, encoding: .utf8)
        try unsupportedSwiftCode.write(to: unsupportedFileURL, atomically: true, encoding: .utf8)

        print("Done! Check supported.swift and unsupported.swift for the results.")
    } catch {
        print("An error occurred: \(error.localizedDescription)")
    }
}

let process = ProcessCommand()
let cli = CLI(name: "swift-code-processor", version: "1.0.0")
cli.commands = [process]
cli.goAndExit()
