import Foundation

public struct ArchiveEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let size: UInt64
    public let modifiedAt: String

    public init(name: String, size: UInt64, modifiedAt: String) {
        self.id = name
        self.name = name
        self.size = size
        self.modifiedAt = modifiedAt
    }
}

public struct CreateArchiveOptions: Sendable {
    public var compressionLevel: Int
    public var password: String?
    public var splitSizeMB: Int?

    public init(
        compressionLevel: Int = 6,
        password: String? = nil,
        splitSizeMB: Int? = nil
    ) {
        self.compressionLevel = max(0, min(9, compressionLevel))
        self.password = password?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.splitSizeMB = splitSizeMB
    }
}

public struct ExtractArchiveOptions: Sendable {
    public var password: String?
    public var overwrite: Bool

    public init(password: String? = nil, overwrite: Bool = true) {
        self.password = password?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.overwrite = overwrite
    }
}

public enum ArchiveOperationError: Error, LocalizedError, Sendable {
    case missingInputs
    case invalidArchivePath
    case malformedListOutput
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingInputs:
            return "No files or folders were selected."
        case .invalidArchivePath:
            return "Archive path must end with .zip"
        case .malformedListOutput:
            return "Archive list output was malformed."
        case .commandFailed(let reason):
            return reason
        }
    }
}
