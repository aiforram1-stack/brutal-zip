import Foundation

public final class ZipArchiveService: @unchecked Sendable {
    private let runner: CommandRunning

    public init(runner: CommandRunning = ShellExecutor()) {
        self.runner = runner
    }

    public func createArchive(
        outputArchive: URL,
        inputItems: [URL],
        options: CreateArchiveOptions = .init()
    ) throws {
        guard !inputItems.isEmpty else {
            throw ArchiveOperationError.missingInputs
        }
        guard outputArchive.pathExtension.lowercased() == "zip" else {
            throw ArchiveOperationError.invalidArchivePath
        }

        let rootDirectory = commonParentDirectory(for: inputItems)
        let relativeInputs = inputItems.map { relativePath(from: rootDirectory, to: $0) }

        var arguments: [String] = ["-r", "-\(max(0, min(9, options.compressionLevel)))"]

        if let password = normalizedPassword(options.password) {
            arguments.append(contentsOf: ["-P", password])
        }

        if let splitSizeMB = options.splitSizeMB, splitSizeMB > 0 {
            arguments.append(contentsOf: ["-s", "\(splitSizeMB)m"])
        }

        arguments.append(outputArchive.path)
        arguments.append(contentsOf: relativeInputs)

        let result = try runner.run(executable: "zip", arguments: arguments, currentDirectory: rootDirectory)
        try ensureSuccess(result, fallbackCommand: "zip")
    }

    public func listEntries(in archive: URL) throws -> [ArchiveEntry] {
        guard archive.pathExtension.lowercased() == "zip" else {
            throw ArchiveOperationError.invalidArchivePath
        }

        let result = try runner.run(executable: "unzip", arguments: ["-l", archive.path], currentDirectory: archive.deletingLastPathComponent())
        try ensureSuccess(result, fallbackCommand: "unzip -l")

        let lines = result.standardOutput.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let regex = try NSRegularExpression(pattern: "^\\s*(\\d+)\\s+(\\d{2}-\\d{2}-\\d{2,4})\\s+(\\d{2}:\\d{2})\\s+(.+)$")

        var entries: [ArchiveEntry] = []
        for line in lines {
            guard let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) else {
                continue
            }

            let rawSize = extract(match: match, at: 1, from: line)
            let date = extract(match: match, at: 2, from: line)
            let time = extract(match: match, at: 3, from: line)
            let name = extract(match: match, at: 4, from: line)

            guard let size = UInt64(rawSize), name != "Name" else {
                continue
            }

            entries.append(.init(name: name, size: size, modifiedAt: "\(date) \(time)"))
        }

        return entries
    }

    public func extractArchive(
        archive: URL,
        to destination: URL,
        options: ExtractArchiveOptions = .init()
    ) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        var arguments: [String] = [options.overwrite ? "-o" : "-n"]
        if let password = normalizedPassword(options.password) {
            arguments.append(contentsOf: ["-P", password])
        }
        arguments.append(contentsOf: [archive.path, "-d", destination.path])

        let result = try runner.run(executable: "unzip", arguments: arguments, currentDirectory: archive.deletingLastPathComponent())
        try ensureSuccess(result, fallbackCommand: "unzip")
    }

    public func testArchive(archive: URL, password: String? = nil) throws {
        var arguments: [String] = ["-t", archive.path]
        if let password = normalizedPassword(password) {
            arguments.append(contentsOf: ["-P", password])
        }

        let result = try runner.run(executable: "unzip", arguments: arguments, currentDirectory: archive.deletingLastPathComponent())
        try ensureSuccess(result, fallbackCommand: "unzip -t")
    }

    public func addItems(
        to archive: URL,
        items: [URL]
    ) throws {
        guard !items.isEmpty else {
            throw ArchiveOperationError.missingInputs
        }

        let rootDirectory = commonParentDirectory(for: items)
        let relativeItems = items.map { relativePath(from: rootDirectory, to: $0) }

        var arguments: [String] = ["-r", "-u", archive.path]
        arguments.append(contentsOf: relativeItems)

        let result = try runner.run(executable: "zip", arguments: arguments, currentDirectory: rootDirectory)
        try ensureSuccess(result, fallbackCommand: "zip -u")
    }

    public func deleteEntries(
        in archive: URL,
        entryNames: [String]
    ) throws {
        guard !entryNames.isEmpty else {
            return
        }

        var arguments: [String] = ["-d", archive.path]
        arguments.append(contentsOf: entryNames)

        let result = try runner.run(executable: "zip", arguments: arguments, currentDirectory: archive.deletingLastPathComponent())
        try ensureSuccess(result, fallbackCommand: "zip -d")
    }

    private func ensureSuccess(_ result: CommandResult, fallbackCommand: String) throws {
        guard result.succeeded else {
            let reason = result.standardError.isEmpty ? result.standardOutput : result.standardError
            throw ArchiveOperationError.commandFailed(
                CommandError.executionFailed(
                    command: fallbackCommand,
                    exitCode: result.exitCode,
                    error: reason
                ).localizedDescription
            )
        }
    }

    private func extract(match: NSTextCheckingResult, at index: Int, from source: String) -> String {
        let range = match.range(at: index)
        guard let swiftRange = Range(range, in: source) else { return "" }
        return String(source[swiftRange])
    }

    private func normalizedPassword(_ candidate: String?) -> String? {
        guard let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty else {
            return nil
        }
        return candidate
    }

    private func commonParentDirectory(for urls: [URL]) -> URL {
        let normalizedParents = urls.map { $0.standardizedFileURL.deletingLastPathComponent().pathComponents }
        guard var prefix = normalizedParents.first else {
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        }

        for path in normalizedParents.dropFirst() {
            var nextPrefix: [String] = []
            for (left, right) in zip(prefix, path) where left == right {
                nextPrefix.append(left)
            }
            prefix = nextPrefix
            if prefix.isEmpty {
                break
            }
        }

        if prefix.isEmpty {
            return URL(fileURLWithPath: "/", isDirectory: true)
        }

        let resolved = NSString.path(withComponents: prefix)
        return URL(fileURLWithPath: resolved, isDirectory: true)
    }

    private func relativePath(from root: URL, to file: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path

        if filePath == rootPath {
            return "."
        }

        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if filePath.hasPrefix(prefix) {
            return String(filePath.dropFirst(prefix.count))
        }

        return file.lastPathComponent
    }
}
