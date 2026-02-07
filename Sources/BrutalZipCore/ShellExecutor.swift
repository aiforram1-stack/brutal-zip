import Foundation

public struct CommandResult: Sendable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public var succeeded: Bool { exitCode == 0 }
}

public enum CommandError: Error, LocalizedError {
    case executableNotFound(String)
    case executionFailed(command: String, exitCode: Int32, error: String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let command):
            return "Required executable not found: \(command)."
        case .executionFailed(let command, let code, let error):
            let trimmed = error.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Command failed (\(command)) with exit code \(code)."
            }
            return "Command failed (\(command)) with exit code \(code): \(trimmed)"
        }
    }
}

public protocol CommandRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        currentDirectory: URL?
    ) throws -> CommandResult
}

public final class ShellExecutor: CommandRunning, @unchecked Sendable {
    public init() {}

    public func run(
        executable: String,
        arguments: [String],
        currentDirectory: URL? = nil
    ) throws -> CommandResult {
        guard let executablePath = resolveExecutablePath(executable) else {
            throw CommandError.executableNotFound(executable)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self)
        )
    }

    private func resolveExecutablePath(_ executable: String) -> String? {
        if executable.contains("/") {
            return FileManager.default.isExecutableFile(atPath: executable) ? executable : nil
        }

        let lookup = Process()
        lookup.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        lookup.arguments = ["which", executable]

        let pipe = Pipe()
        lookup.standardOutput = pipe
        lookup.standardError = Pipe()

        do {
            try lookup.run()
            lookup.waitUntilExit()
        } catch {
            return nil
        }

        guard lookup.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let resolved = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return resolved.isEmpty ? nil : resolved
    }
}
