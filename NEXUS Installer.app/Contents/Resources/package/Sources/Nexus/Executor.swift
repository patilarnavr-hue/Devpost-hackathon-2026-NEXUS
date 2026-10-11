import Foundation

actor Executor {
    static let shared = Executor()
    
    enum ToolError: Error {
        case notFound(String)
        case permissionDenied(String)
        case executionFailed(String)
    }
    
    struct FileResult {
        let path: String
        let content: String?
        let success: Bool
        let error: String?
    }
    
    struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let success: Bool
    }
    
    // MARK: - FileTool
    
    func readFile(path: String) async -> FileResult {
        let expanded = expandPath(path)
        do {
            let content = try String(contentsOfFile: expanded, encoding: .utf8)
            return FileResult(path: path, content: content, success: true, error: nil)
        } catch {
            return FileResult(path: path, content: nil, success: false, error: error.localizedDescription)
        }
    }
    
    func writeFile(path: String, content: String) async -> FileResult {
        let expanded = expandPath(path)
        let url = URL(fileURLWithPath: expanded)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try content.write(toFile: expanded, atomically: true, encoding: .utf8)
            return FileResult(path: path, content: content, success: true, error: nil)
        } catch {
            return FileResult(path: path, content: nil, success: false, error: error.localizedDescription)
        }
    }
    
    func editFile(path: String, oldText: String, newText: String) async -> FileResult {
        let expanded = expandPath(path)
        let result = await readFile(path: path)
        guard result.success, let content = result.content else {
            return FileResult(path: path, content: nil, success: false, error: "Failed to read file")
        }
        if content.contains(oldText) {
            let newContent = content.replacingOccurrences(of: oldText, with: newText)
            return await writeFile(path: path, content: newContent)
        } else {
            return FileResult(path: path, content: nil, success: false, error: "Old text not found in file")
        }
    }
    
    func listDirectory(path: String) async -> FileResult {
        let expanded = expandPath(path)
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: expanded)
            let output = contents.joined(separator: "\n")
            return FileResult(path: path, content: output, success: true, error: nil)
        } catch {
            return FileResult(path: path, content: nil, success: false, error: error.localizedDescription)
        }
    }
    
    // MARK: - ProcessTool
    
    func runProcess(command: String, cwd: String? = nil) async -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        if let cwd = cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: expandPath(cwd))
        }
        
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
            
            return ProcessResult(
                exitCode: exitCode,
                stdout: stdout,
                stderr: stderr,
                success: exitCode == 0
            )
        } catch {
            return ProcessResult(
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription,
                success: false
            )
        }
    }
    
    // MARK: - Helpers
    
    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~") {
            return (path as NSString).expandingTildeInPath
        }
        return path
    }
}