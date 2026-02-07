import AppKit
import BrutalZipCore
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedArchiveURL: URL?
    @Published var entries: [ArchiveEntry] = []
    @Published var selectedEntryNames: Set<String> = []
    @Published var selectedInputItems: [URL] = []
    @Published var extractionDestination: URL?

    @Published var createPassword: String = ""
    @Published var actionPassword: String = ""
    @Published var compressionLevel: Double = 6
    @Published var splitSizeMBText: String = ""
    @Published var overwriteOnExtract: Bool = true

    @Published var isBusy: Bool = false
    @Published var statusLine: String = "READY"
    @Published var logs: [String] = []

    private let archiveService: ZipArchiveService

    init(archiveService: ZipArchiveService = ZipArchiveService()) {
        self.archiveService = archiveService
    }

    func chooseInputItems() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            selectedInputItems = panel.urls
            appendLog("Selected \(panel.urls.count) item(s) for archiving.")
        }
    }

    func createArchiveFromSelection() {
        guard !selectedInputItems.isEmpty else {
            appendLog("No source items selected.")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.zip]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "brutal.zip"
        savePanel.prompt = "Create"

        guard savePanel.runModal() == .OK, let targetURL = savePanel.url else { return }

        let items = selectedInputItems
        let options = CreateArchiveOptions(
            compressionLevel: Int(compressionLevel.rounded()),
            password: createPassword,
            splitSizeMB: Int(splitSizeMBText)
        )
        let service = archiveService

        runOperation("Creating archive") {
            try service.createArchive(outputArchive: targetURL, inputItems: items, options: options)
        } onSuccess: {
            self.selectedArchiveURL = targetURL
            self.refreshEntries()
        }
    }

    func openArchive() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip]
        panel.prompt = "Open"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        selectedArchiveURL = url
        appendLog("Opened archive: \(url.lastPathComponent)")
        refreshEntries()
    }

    func refreshEntries() {
        guard let archive = selectedArchiveURL else {
            entries = []
            return
        }
        let service = archiveService

        runOperation("Refreshing entries", task: {
            try service.listEntries(in: archive)
        }, onSuccess: { listedEntries in
            self.entries = listedEntries
            self.selectedEntryNames = []
        })
    }

    func chooseExtractionDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"

        if panel.runModal() == .OK, let url = panel.url {
            extractionDestination = url
            appendLog("Extraction folder set to: \(url.path)")
        }
    }

    func extractArchive() {
        guard let archive = selectedArchiveURL else {
            appendLog("Open an archive before extraction.")
            return
        }

        let destination: URL
        if let extractionDestination {
            destination = extractionDestination
        } else {
            destination = archive.deletingLastPathComponent()
        }

        let options = ExtractArchiveOptions(password: actionPassword, overwrite: overwriteOnExtract)
        let service = archiveService

        runOperation("Extracting archive") {
            try service.extractArchive(archive: archive, to: destination, options: options)
        }
    }

    func testArchiveIntegrity() {
        guard let archive = selectedArchiveURL else {
            appendLog("Open an archive before testing.")
            return
        }

        let password = actionPassword
        let service = archiveService
        runOperation("Testing archive") {
            try service.testArchive(archive: archive, password: password)
        }
    }

    func addItemsToArchive() {
        guard let archive = selectedArchiveURL else {
            appendLog("Open an archive before adding files.")
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"

        guard panel.runModal() == .OK else { return }

        let urls = panel.urls
        let service = archiveService
        runOperation("Adding items") {
            try service.addItems(to: archive, items: urls)
        } onSuccess: {
            self.refreshEntries()
        }
    }

    func deleteSelectedEntries() {
        guard let archive = selectedArchiveURL else {
            appendLog("Open an archive before deleting entries.")
            return
        }
        let toDelete = Array(selectedEntryNames)
        guard !toDelete.isEmpty else {
            appendLog("Select one or more entries to delete.")
            return
        }
        let service = archiveService

        runOperation("Deleting entries") {
            try service.deleteEntries(in: archive, entryNames: toDelete)
        } onSuccess: {
            self.refreshEntries()
        }
    }

    private func runOperation(
        _ title: String,
        task: @escaping @Sendable () throws -> Void,
        onSuccess: (() -> Void)? = nil
    ) {
        isBusy = true
        statusLine = title.uppercased()
        appendLog("\(title)...")

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try task()
                }.value

                isBusy = false
                statusLine = "READY"
                appendLog("\(title) completed.")
                onSuccess?()
            } catch {
                isBusy = false
                statusLine = "ERROR"
                appendLog(error.localizedDescription)
            }
        }
    }

    private func runOperation<T: Sendable>(
        _ title: String,
        task: @escaping @Sendable () throws -> T,
        onSuccess: @escaping (T) -> Void
    ) {
        isBusy = true
        statusLine = title.uppercased()
        appendLog("\(title)...")

        Task {
            do {
                let value = try await Task.detached(priority: .userInitiated) {
                    try task()
                }.value

                isBusy = false
                statusLine = "READY"
                appendLog("\(title) completed.")
                onSuccess(value)
            } catch {
                isBusy = false
                statusLine = "ERROR"
                appendLog(error.localizedDescription)
            }
        }
    }

    private func appendLog(_ message: String) {
        let timestamp = Self.logFormatter.string(from: Date())
        logs.insert("[\(timestamp)] \(message)", at: 0)
        if logs.count > 200 {
            logs = Array(logs.prefix(200))
        }
    }

    private static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
