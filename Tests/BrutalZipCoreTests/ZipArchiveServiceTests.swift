import BrutalZipCore
import Foundation
import Testing

struct ZipArchiveServiceTests {
    @Test
    func createListAndExtractArchive() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let inputDir = temp.appendingPathComponent("payload", isDirectory: true)
        try FileManager.default.createDirectory(at: inputDir, withIntermediateDirectories: true)
        let textFile = inputDir.appendingPathComponent("readme.txt")
        try "BrutalZip".data(using: .utf8)?.write(to: textFile)

        let archive = temp.appendingPathComponent("build.zip")
        let service = ZipArchiveService()

        try service.createArchive(outputArchive: archive, inputItems: [inputDir])

        #expect(FileManager.default.fileExists(atPath: archive.path))

        let entries = try service.listEntries(in: archive)
        #expect(entries.contains(where: { $0.name.hasSuffix("payload/readme.txt") }))

        let extraction = temp.appendingPathComponent("extracted", isDirectory: true)
        try service.extractArchive(archive: archive, to: extraction)

        let extractedFile = extraction.appendingPathComponent("payload/readme.txt")
        let extractedContent = try String(contentsOf: extractedFile)
        #expect(extractedContent == "BrutalZip")
    }

    @Test
    func addAndDeleteEntries() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = temp.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let first = source.appendingPathComponent("one.txt")
        let second = source.appendingPathComponent("two.txt")
        try "one".write(to: first, atomically: true, encoding: .utf8)
        try "two".write(to: second, atomically: true, encoding: .utf8)

        let archive = temp.appendingPathComponent("pack.zip")
        let service = ZipArchiveService()

        try service.createArchive(outputArchive: archive, inputItems: [first])
        try service.addItems(to: archive, items: [second])

        var entries = try service.listEntries(in: archive)
        #expect(entries.contains(where: { $0.name.hasSuffix("one.txt") }))
        #expect(entries.contains(where: { $0.name.hasSuffix("two.txt") }))

        guard let entryToDelete = entries.first(where: { $0.name.hasSuffix("two.txt") }) else {
            throw ArchiveOperationError.commandFailed("Added file did not appear in listing.")
        }

        try service.deleteEntries(in: archive, entryNames: [entryToDelete.name])
        entries = try service.listEntries(in: archive)
        #expect(entries.allSatisfy { !$0.name.hasSuffix("two.txt") })
    }

    @Test
    func passwordProtectedArchiveRequiresPassword() throws {
        let temp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: temp) }

        let securedFile = temp.appendingPathComponent("secret.txt")
        try "classified".write(to: securedFile, atomically: true, encoding: .utf8)

        let archive = temp.appendingPathComponent("secret.zip")
        let service = ZipArchiveService()

        try service.createArchive(
            outputArchive: archive,
            inputItems: [securedFile],
            options: .init(compressionLevel: 6, password: "hunter2")
        )

        #expect(throws: Error.self) {
            try service.testArchive(archive: archive, password: "wrong")
        }

        #expect(throws: Error.self) {
            let destination = temp.appendingPathComponent("bad", isDirectory: true)
            try service.extractArchive(
                archive: archive,
                to: destination,
                options: .init(password: nil, overwrite: true)
            )
        }

        let goodDestination = temp.appendingPathComponent("good", isDirectory: true)
        try service.extractArchive(
            archive: archive,
            to: goodDestination,
            options: .init(password: "hunter2", overwrite: true)
        )

        let extracted = goodDestination.appendingPathComponent("secret.txt")
        let value = try String(contentsOf: extracted)
        #expect(value == "classified")
    }

    private func makeTempDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let path = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }
}
