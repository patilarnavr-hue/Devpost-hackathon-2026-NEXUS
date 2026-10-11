// Verifier — runs FixturePackage self-test and captures real exit code
// This is the check-of-record: only exit 0 = success

import Foundation

struct Verifier {
    /// Locate FixturePackage portably: env override → walk up from CWD → home Desktop/Documents → CWD.
    static let fixturePath: String = {
        if let env = ProcessInfo.processInfo.environment["NEXUS_FIXTURE"], !env.isEmpty {
            return env
        }
        let fm = FileManager.default
        var dir = URL(fileURLWithPath: fm.currentDirectoryPath)
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("FixturePackage")
            if fm.fileExists(atPath: candidate.path) { return candidate.path }
            dir.deleteLastPathComponent()
        }
        let home = URL(fileURLWithPath: NSHomeDirectory())
        for sub in ["Desktop/FixturePackage", "Documents/FixturePackage", "FixturePackage"] {
            let candidate = home.appendingPathComponent(sub)
            if fm.fileExists(atPath: candidate.path) { return candidate.path }
        }
        return fm.currentDirectoryPath
    }()
    
    struct Result {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let success: Bool
        let timestamp: Date
    }
    
    static func run() async -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "FixtureTests"]
        process.currentDirectoryURL = URL(fileURLWithPath: fixturePath)
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""
            let exitCode = process.terminationStatus
            
            return Result(
                exitCode: exitCode,
                stdout: stdout,
                stderr: stderr,
                success: exitCode == 0,
                timestamp: Date()
            )
        } catch {
            return Result(
                exitCode: -1,
                stdout: "",
                stderr: "Failed to launch: \(error)",
                success: false,
                timestamp: Date()
            )
        }
    }
    
    static func runAndLog() async -> Result {
        let result = await run()
        let logEntry = """
        [VERIFIER \(ISO8601DateFormatter().string(from: result.timestamp))]
        Exit: \(result.exitCode) | Success: \(result.success)
        STDOUT:
        \(result.stdout)
        STDERR:
        \(result.stderr)
        ---
        """
        print(logEntry)
        return result
    }
}