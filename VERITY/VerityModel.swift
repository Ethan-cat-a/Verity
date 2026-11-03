import Foundation
import AppKit
import Combine

struct VerityFile: Identifiable {
    let id = UUID()
    let url: URL

    var name: String { url.lastPathComponent }
    var fileExtension: String { url.pathExtension.isEmpty ? "Unknown" : url.pathExtension.uppercased() }

    var sizeDescription: String {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            if values.isDirectory == true { return "Folder" }
            let bytes = Int64(values.fileSize ?? 0)
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        } catch {
            return "Size unavailable"
        }
    }
}

@MainActor
final class VerityModel: ObservableObject {
    static let shared = VerityModel()

    @Published var currentFile: VerityFile?
    @Published var statusMessage = "Hello! I'm Verity, your personal helper friend."
    @Published var lastEatenFileName: String?
    @Published var isEating = false
    @Published var mood: VerityMood = .happy
    private var hasSecurityScopedAccess = false

    private init() {}

    func accept(fileURL: URL) {
        guard fileURL.isFileURL else {
            statusMessage = "That isn't a file I can eat."
            return
        }

        // Release the previous file's scope before acquiring another one.
        releaseCurrentFileAccess()
        hasSecurityScopedAccess = fileURL.startAccessingSecurityScopedResource()
        // Keep security-scoped access alive while the file inspector is open.
        currentFile = VerityFile(url: fileURL)
        lastEatenFileName = fileURL.lastPathComponent
        statusMessage = "Ooooh, \(fileURL.lastPathComponent). What have we got here?"
        isEating = true
        mood = .eating

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard let self else { return }
            self.isEating = false
            self.mood = .happy
            self.statusMessage = "I ate it. Want me to understand it?"
        }
    }

    func closeFile() {
        releaseCurrentFileAccess()
        currentFile = nil
        mood = .happy
        statusMessage = "That was tasty. Feed me something else!"
    }

    /// Balances the security-scoped access acquired for the currently open file.
    private func releaseCurrentFileAccess() {
        if hasSecurityScopedAccess, let url = currentFile?.url {
            url.stopAccessingSecurityScopedResource()
        }
        hasSecurityScopedAccess = false
    }

    func setStatus(_ message: String) {
        statusMessage = message
    }

    func setMood(_ newMood: VerityMood) {
        mood = newMood
    }
}

/// File actions interact with AppKit and the main-actor Verity model.
/// Marking the whole namespace @MainActor fixes calls into VerityModel.shared
/// from synchronous, nonisolated static methods (the reported line 81 error).
@MainActor
enum VerityFileActions {
    static var vaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Verity Vault", isDirectory: true)
    }

    static func openVault() {
        do {
            try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
            NSWorkspace.shared.open(vaultURL)
        } catch {
            VerityModel.shared.setStatus("I couldn't open the Vault: \(error.localizedDescription)")
        }
    }

    /// Copies the original into Verity Vault. It never removes the source file.
    static func saveCopyToVault(_ source: URL) throws -> URL {
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        let destination = uniqueDestination(for: source.lastPathComponent, in: vaultURL)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func moveToTrash(_ source: URL) throws {
        try FileManager.default.trashItem(at: source, resultingItemURL: nil)
    }

    static func uniqueDestination(for filename: String, in directory: URL) -> URL {
        let initial = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: initial.path) else { return initial }

        let original = URL(fileURLWithPath: filename)
        let base = original.deletingPathExtension().lastPathComponent
        let ext = original.pathExtension
        var index = 2
        while true {
            let candidateName = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}
