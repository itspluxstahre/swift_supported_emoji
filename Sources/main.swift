import Foundation
import SwiftCLI

func 🖨️(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
}

struct SwiftCode: Codable {
    let emoji: String
    let label: String
    let hexcode: String
    let skins: [SwiftCode]?
    var index: Int?
}

class ProcessCommand: Command {
    let name = "process"
    let shortDescription = "This command processes the swift code"

    let jsonData = Key<String>("-j", "--json", description: "Path to JSON data file")
    let supportedFile = Key<String>("-s", "--supportedFile", description: "Path for supported swift file")
    let unsupportedFile = Key<String>("-u", "--unsupportedFile", description: "Path for unsupported swift file")
    let resultsFile = Key<String>("-r", "--resultsFile", description: "Path for plaintext results file")
    let resultsUnsupportedFile = Key<String>("-f", "--resultsUnsupportedFile", description: "Path for plaintext results file for unsupported")
    let overwrite = Flag("-o", "--overwrite", description: "Overwrite existing supported and unsupported swift files.")

    // Helper function for handling file overwrites
    private func handleOverwrite(for filePath: String) -> Bool {
        if FileManager.default.fileExists(atPath: filePath), !overwrite.value {
            🖨️("\(filePath) already exists. Overwrite? [Y/N]")
            if let response = readLine(), response.lowercased() != "y" {
                🖨️("Skipped: \(filePath)")
                return false
            }
        }
        return true
    }

    func execute() throws {
        let jsonDataPath = jsonData.value ?? "data.raw.json"
        let supportedFilePath = supportedFile.value ?? "supported.swift"
        let unsupportedFilePath = unsupportedFile.value ?? "unsupported.swift"
        let resultsFilePath = resultsFile.value ?? "supported.md"
        let resultsUnsupportedFilePath = resultsUnsupportedFile.value ?? "unsupported.md"

        guard handleOverwrite(for: supportedFilePath),
              handleOverwrite(for: unsupportedFilePath) else { return }

        try main(
            jsonDataPath: jsonDataPath,
            supportedFilePath: supportedFilePath,
            unsupportedFilePath: unsupportedFilePath,
            resultsFilePath: resultsFilePath,
            resultsUnsupportedFilePath: resultsUnsupportedFilePath
        )
    }
}

func testSwiftCode(swiftCode: String) throws -> Bool {
    let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("swift")

    defer { try? FileManager.default.removeItem(at: tempFileURL) }

    try swiftCode.write(to: tempFileURL, atomically: true, encoding: .utf8)

    let process = Process()
    let pipe = Pipe()
    let errorPipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    process.arguments = [tempFileURL.path]
    process.standardOutput = pipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return errorOutput.isEmpty
}

// Unified file writing for supported and unsupported Swift codes
func writeFiles(supported: String, unsupported: String, results: String, unsupportedResults: String, paths: (URL, URL, URL, URL)) throws {
    try supported.write(to: paths.0, atomically: true, encoding: .utf8)
    try unsupported.write(to: paths.1, atomically: true, encoding: .utf8)
    try results.write(to: paths.2, atomically: true, encoding: .utf8)
    try unsupportedResults.write(to: paths.3, atomically: true, encoding: .utf8)
}

func getUnicodeScalars(string: String) -> [String] {
    return string.unicodeScalars.map { "U+\(String(format: "%04X", $0.value))" }
}

// Spinner for progress indication with elapsed time and ETA
let spinnerFrames = ["|", "/", "-", "\\"]
func showSpinner(progress: @escaping () -> Int, total: Int, startTime: Date, completionSignal: DispatchSemaphore, spinnerDone: DispatchSemaphore) {
    var spinnerIndex = 0
    while true {
        let currentProgress = progress()
        let percentage = Double(currentProgress) / Double(total) * 100.0
        let frame = spinnerFrames[spinnerIndex % spinnerFrames.count]
        spinnerIndex += 1

        // Calculate elapsed time
        let elapsedTime = Date().timeIntervalSince(startTime)
        let elapsedFormatted = formatTime(elapsedTime)

        // Calculate estimated remaining time
        let remainingTime = currentProgress > 0
            ? (elapsedTime / Double(currentProgress)) * Double(total - currentProgress)
            : 0
        let remainingFormatted = formatTime(remainingTime)

        // Display spinner with percentage, elapsed time, and ETA
        🖨️("\r[\(frame)] Testing: \(currentProgress) of \(total) (\(String(format: "%.1f", percentage))%) | Elapsed: \(elapsedFormatted) | ETA: \(remainingFormatted)", terminator: "")
        fflush(stdout)

        if currentProgress >= total {
            break
        }
        usleep(100_000) // Small delay for smoother animation
    }

    // Wait for the main thread to finalize its logic
    completionSignal.wait()

    // Print a clean line after completion
    🖨️("\nTesting complete!")
    fflush(stdout)

    // Notify that the spinner has finished
    spinnerDone.signal()
}

// Format time as HH:mm:ss
func formatTime(_ interval: TimeInterval) -> String {
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60
    let seconds = Int(interval) % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

func main(jsonDataPath: String, supportedFilePath: String, unsupportedFilePath: String, resultsFilePath: String, resultsUnsupportedFilePath: String) throws {
    let fileManager = FileManager.default
    let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)

    let jsonDataURL = currentDirectoryURL.appendingPathComponent(jsonDataPath)
    let supportedFileURL = currentDirectoryURL.appendingPathComponent(supportedFilePath)
    let unsupportedFileURL = currentDirectoryURL.appendingPathComponent(unsupportedFilePath)
    let resultsFileURL = currentDirectoryURL.appendingPathComponent(resultsFilePath)
    let resultsUnsupportedFileURL = currentDirectoryURL.appendingPathComponent(resultsUnsupportedFilePath)

    let data = try Data(contentsOf: jsonDataURL)
    let baseCodes = try JSONDecoder().decode([SwiftCode].self, from: data)

    let swiftCodes = baseCodes.flatMap { [$0] + ($0.skins ?? []) }.enumerated().map {
        var code = $1
        code.index = $0
        return code
    }

    var supportedCodes = [SwiftCode]()
    var unsupportedCodes = [SwiftCode]()
    var progress = 0

    let lock = NSLock()
    let startTime = Date()
    let completionSignal = DispatchSemaphore(value: 0)
    let spinnerDone = DispatchSemaphore(value: 0)

    // Start spinner
    DispatchQueue.global(qos: .userInteractive).async {
        showSpinner(progress: { progress }, total: swiftCodes.count, startTime: startTime, completionSignal: completionSignal, spinnerDone: spinnerDone)
    }

    DispatchQueue.concurrentPerform(iterations: swiftCodes.count) { index in
        let item = swiftCodes[index]
        let swiftLine = "func \(item.emoji)() { return } /* Name: \(item.label) */"
        let isSupported = (try? testSwiftCode(swiftCode: swiftLine)) == true

        lock.lock()
        defer { lock.unlock() }

        progress += 1
        if isSupported {
            supportedCodes.append(item)
        } else {
            unsupportedCodes.append(item)
        }
    }

    supportedCodes.sort { $0.index! < $1.index! }
    unsupportedCodes.sort { $0.index! < $1.index! }

    let supportedSwiftCode = supportedCodes.map {
        "func \($0.emoji)() { return } /* Name: \($0.label) */\n"
    }.joined()

    let unsupportedSwiftCode = unsupportedCodes.map {
        "func \($0.emoji)() { return } /* Name: \($0.label) */\n"
    }.joined()

    let tableHeader = "| Emoji | Name | Codepoints |\n| ----- | ---- | ---------- |\n"
    let resultsFileLines = supportedCodes.reduce(into: tableHeader) { result, item in
        let codepoints = getUnicodeScalars(string: item.emoji).joined(separator: " ")
        result += "| \(item.emoji) | \(item.label) | \(codepoints) |\n"
    }

    let resultsUnsupportedFileLines = unsupportedCodes.reduce(into: tableHeader) { result, item in
        let codepoints = getUnicodeScalars(string: item.emoji).joined(separator: " ")
        result += "| \(item.emoji) | \(item.label) | \(codepoints) |\n"
    }

    try writeFiles(
        supported: supportedSwiftCode,
        unsupported: unsupportedSwiftCode,
        results: resultsFileLines,
        unsupportedResults: resultsUnsupportedFileLines,
        paths: (supportedFileURL, unsupportedFileURL, resultsFileURL, resultsUnsupportedFileURL)
    )

    completionSignal.signal()
    spinnerDone.wait()

    🖨️("Done! Results saved in \(supportedFilePath) and \(unsupportedFilePath).")
}

let process = ProcessCommand()
let cli = CLI(name: "swift-emoji-processor", version: "1.0.0")
cli.commands = [process]
cli.goAndExit()
