import Foundation

func testSwiftCode(swiftCode: String) -> Bool {
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
        return false
    }
}
func main() {
    do {
        let fileManager = FileManager.default
        let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let jsonDataURL = currentDirectoryURL.appendingPathComponent("data.raw.json")
        
        // Change to write in the current directory
        let supportedFileURL = currentDirectoryURL.appendingPathComponent("supported.swift")
        let unsupportedFileURL = currentDirectoryURL.appendingPathComponent("unsupported.swift")
        
        let data = try Data(contentsOf: jsonDataURL)
        guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            print("JSON data could not be parsed into the expected format.")
            return
        }
        
        var supportedSwiftCode = ""
        var unsupportedSwiftCode = ""
        
        for item in jsonArray {
            if let emoji = item["emoji"] as? String, let label = item["label"] as? String {
                 let swiftLine = "let \(emoji) = 1 /* \(label) */\n"
                
                if testSwiftCode(swiftCode: swiftLine) {
                    supportedSwiftCode += swiftLine
                } else {
                    unsupportedSwiftCode += swiftLine
                }
            }
        }
        
        try supportedSwiftCode.write(to: supportedFileURL, atomically: true, encoding: .utf8)
        try unsupportedSwiftCode.write(to: unsupportedFileURL, atomically: true, encoding: .utf8)
        
        print("Done! Check supported.swift and unsupported.swift for the results.")
    } catch {
        print("An error occurred: \(error.localizedDescription)")
    }
}
main()
