import Foundation
import SwiftCLI

// Updated SwiftCode and Skin structs
// Same fields for both main emojis and skin variations
struct SwiftCode: Codable {
  let emoji: String
  let label: String
  let hexcode: String
  let skins: [SwiftCode]?
}

class ProcessCommand: Command {
  let name = "process"
  let shortDescription = "This command process the swift code"

  let jsonData = Key<String>(
    "-j", "--json", description: "Path to JSON data file. Use the format lowerName=VALUE")
  let supportedFile = Key<String>(
    "-s", "--supportedFile",
    description: "Path for supported swift file. Use the format upperName=VALUE")
  let unsupportedFile = Key<String>(
    "-u", "--unsupportedFile",
    description: "Path for unsupported swift file. Use the format specialChar=VALUE")
  let resultsFile = Key<String>(
    "-r", "--resultsFile",
    description: "Path for plaintext resultsfile. Use the format specialChar=VALUE")
  let resultsUnsupportedFile = Key<String>(
    "-f", "--resultsUnsupportedFile",
    description: "Path for plaintext resultsfile. Use the format specialChar=VALUE")
  let overwrite = Flag(
    "-o", "--overwrite", description: "Overwrite existing supported and unsupported swift files.")

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

    var resultsFilePath = "supported.md"
    if let resulFile = resultsFile.value {
      resultsFilePath = resulFile
    }

    var resultsUnsupportedFilePath = "unsupported.md"
    if let resulUnsupFile = resultsUnsupportedFile.value {
      resultsUnsupportedFilePath = resulUnsupFile
    }
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: supportedFilePath), !overwrite.value {
      print("\(supportedFilePath) already exists. Do you want to overwrite? Y/N")

      if let userInput = readLine(), userInput.lowercased() != "y" {
        print("File \(supportedFilePath) was not overwritten.")
        return
      }
    }

    if fileManager.fileExists(atPath: unsupportedFilePath), !overwrite.value {
      print("\(unsupportedFilePath) already exists. Do you want to overwrite? Y/N")
      if let userInput = readLine(), userInput.lowercased() != "y" {
        print("File \(unsupportedFilePath) was not overwritten.")
        return
      }
    }

    try main(
      jsonDataPath: jsonDataPath, supportedFilePath: supportedFilePath,
      unsupportedFilePath: unsupportedFilePath, resultsFilePath: resultsFilePath, resultsUnsupportedFilePath: resultsUnsupportedFilePath)
  }
}

func testSwiftCode(swiftCode: String) throws -> Bool {
  let tempDirectory = NSTemporaryDirectory()
  let tempFileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("swift")

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

    let cleanedOutput = (output ?? "").replacingOccurrences(of: "<unknown>:0: warning: using (deprecated) legacy driver, Swift installation does not contain swift-driver at: '/Library/Developer/CommandLineTools/usr/bin/swift-driver-new'\n", with: "")
      
    try FileManager.default.removeItem(at: tempFileURL)
    
    return cleanedOutput.isEmpty 
  } catch {
    print("An error occurred: \(error.localizedDescription)")
    throw error
  }
}

func getUnicodeScalars(string: String) -> [String] {
  return string.unicodeScalars.map { "U+\(String(format: "%04X", $0.value))" }
}

func getSwiftVersion() -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "--version"]

    let pipe = Pipe()
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    } catch {
        print("Error: \(error.localizedDescription)")
    }

    return nil
}

func main(jsonDataPath: String, supportedFilePath: String, unsupportedFilePath: String, resultsFilePath: String, resultsUnsupportedFilePath: String) throws {

  do {
    let fileManager = FileManager.default
    let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
    let jsonDataURL = currentDirectoryURL.appendingPathComponent(jsonDataPath)

    let supportedFileURL = currentDirectoryURL.appendingPathComponent(supportedFilePath)
    let unsupportedFileURL = currentDirectoryURL.appendingPathComponent(unsupportedFilePath)
    let resultsFileURL = currentDirectoryURL.appendingPathComponent(resultsFilePath)
    let resultsUnsupportedFileURL = currentDirectoryURL.appendingPathComponent(resultsUnsupportedFilePath)
    let data = try Data(contentsOf: jsonDataURL)
    let baseCodes = try JSONDecoder().decode([SwiftCode].self, from: data)

    // Flatten the array by including the skins into the main array
    var swiftCodes: [SwiftCode] = []
    for baseCode in baseCodes {
      swiftCodes.append(baseCode)
      if let skins = baseCode.skins {
        swiftCodes.append(contentsOf: skins)
      }
    }
    var supportedSwiftCode = ""
    var unsupportedSwiftCode = ""
    var resultsFileLines: String = ""
    resultsFileLines += "| Emoji | Name | Codepoints |\n"
    resultsFileLines += "| ----- | ---- | ---------- |\n"
    
    var resultsUnsupportedFileLines = resultsFileLines
    let len = swiftCodes.count
    var count = 1;
    for item in swiftCodes {
      let codepoints = getUnicodeScalars(string: item.emoji).joined(separator: " ")
      let swiftLine = "func \(item.emoji)() { return }\t/* Name: \(item.label), Codepoints: \(codepoints) */\n"
      print("\r\u{001B}[1;33mTesting: \u{001B}[0;0m \(count) of \(len)", terminator: "\r")
      if try testSwiftCode(swiftCode: swiftLine) {

       
        supportedSwiftCode += swiftLine
        resultsFileLines +=
          "| \(item.emoji) | \(item.label) | \(codepoints) |\n"
      } else {
        
        unsupportedSwiftCode += swiftLine
        resultsUnsupportedFileLines +=
          "| \(item.emoji) | \(item.label) | \(codepoints) |\n"
      }
      count += 1
    }

if let swiftVersion = getSwiftVersion() {
    supportedSwiftCode += "\n/* Generated by: \(swiftVersion) */\n"
    unsupportedSwiftCode += "\n/* Generated by: \(swiftVersion) */\n"

    resultsFileLines += "\nGenerated by: \(swiftVersion)\n"
    resultsUnsupportedFileLines += "\nGenerated by: \(swiftVersion)\n"
} else {
    print("Unable to retrieve Swift version.")
}



    try supportedSwiftCode.write(to: supportedFileURL, atomically: true, encoding: .utf8)
    try unsupportedSwiftCode.write(to: unsupportedFileURL, atomically: true, encoding: .utf8)
    try resultsFileLines.write(to: resultsFileURL, atomically: true, encoding: .utf8)
    try resultsUnsupportedFileLines.write(to: resultsUnsupportedFileURL, atomically: true, encoding: .utf8)

    print("Done! Check supported.swift and unsupported.swift for the results.")
  } catch {
    print("An error occurred: \(error.localizedDescription)")
  }
}

let process = ProcessCommand()
let cli = CLI(name: "swift-emoji-processor", version: "1.0.0")
cli.commands = [process]
cli.goAndExit()
