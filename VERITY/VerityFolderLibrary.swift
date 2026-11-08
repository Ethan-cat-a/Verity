import Foundation
import Combine

/// Optional, folder-scoped local document search. Extracted text stays in memory;
/// only passages selected for a user's question are sent to NOVA.
@MainActor
final class VerityFolderLibrary: ObservableObject {
    static let shared = VerityFolderLibrary()

    private static let enabledKey = "verity.folderLibrary.enabled"
    private static let bookmarkKey = "verity.folderLibrary.bookmark"
    private static let maximumIndexedFiles = 2_000
    private static let maximumIndexedCharacters = 12_000_000
    private static let refreshInterval: TimeInterval = 15 * 60

    @Published private(set) var isEnabled: Bool
    @Published private(set) var folderName: String?
    @Published private(set) var isIndexing = false
    @Published private(set) var indexedFileCount = 0
    @Published private(set) var status = "Folder search is off."
    @Published private(set) var errorMessage: String?
    @Published private(set) var indexedFiles: [VeritySharedConversationFile] = []

    private let defaults: UserDefaults
    private var indexingTask: Task<ScanResult, Error>?
    private var indexingID: UUID?
    private var hasCompletedIndex = false
    private var lastIndexedAt: Date?

    private struct ScanResult: Sendable {
        let files: [VeritySharedConversationFile]
        let skippedCount: Int
        let reachedLimit: Bool
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Self.enabledKey: false])
        let bookmark = defaults.data(forKey: Self.bookmarkKey)
        isEnabled = defaults.bool(forKey: Self.enabledKey) && bookmark != nil
        if let bookmark, let folderURL = try? Self.resolveBookmark(bookmark).url {
            folderName = folderURL.lastPathComponent
        }
        if !isEnabled {
            defaults.removeObject(forKey: Self.enabledKey)
            status = "Folder search is off."
        } else {
            status = "Folder access is enabled. VERITY will index it locally when you ask a question."
        }
    }

    /// Save a bookmark only after the user chooses a folder in the system panel.
    func enable(folderURL: URL) throws {
        let values = try folderURL.resourceValues(forKeys: [.isDirectoryKey])
        guard folderURL.isFileURL, values.isDirectory == true else {
            throw FolderLibraryError.folderRequired
        }

        let bookmark: Data
        do {
            bookmark = try folderURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            // VERITY is currently distributed without App Sandbox. A plain
            // bookmark keeps folder selection usable in that configuration.
            bookmark = try folderURL.bookmarkData()
        }

        cancelIndexingAndClearCache()
        defaults.set(bookmark, forKey: Self.bookmarkKey)
        defaults.set(true, forKey: Self.enabledKey)
        isEnabled = true
        folderName = folderURL.lastPathComponent
        errorMessage = nil
        status = "Folder selected. VERITY will index supported documents locally."
    }

    /// Disabling removes the saved bookmark and the in-memory text index.
    func disable() {
        cancelIndexingAndClearCache()
        defaults.removeObject(forKey: Self.enabledKey)
        defaults.removeObject(forKey: Self.bookmarkKey)
        isEnabled = false
        folderName = nil
        errorMessage = nil
        status = "Folder search is off."
    }

    func ensureIndexIsFresh() async {
        guard isEnabled else { return }
        if hasCompletedIndex,
           let lastIndexedAt,
           Date().timeIntervalSince(lastIndexedAt) < Self.refreshInterval {
            return
        }
        await refreshIndex()
    }

    func refreshIndex() async {
        guard isEnabled else { return }

        let task: Task<ScanResult, Error>
        let taskID: UUID
        if let existing = indexingTask, let existingID = indexingID {
            task = existing
            taskID = existingID
        } else {
            indexedFiles = []
            indexedFileCount = 0
            hasCompletedIndex = false
            lastIndexedAt = nil
            guard let bookmark = defaults.data(forKey: Self.bookmarkKey) else {
                errorMessage = FolderLibraryError.permissionUnavailable.localizedDescription
                status = "Choose the folder again to restore access."
                return
            }

            do {
                let resolution = try Self.resolveBookmark(bookmark)
                folderName = resolution.url.lastPathComponent
                if resolution.isStale {
                    let refreshed = try Self.makeBookmark(for: resolution.url)
                    defaults.set(refreshed, forKey: Self.bookmarkKey)
                }

                taskID = UUID()
                indexingID = taskID
                isIndexing = true
                errorMessage = nil
                status = "Indexing supported documents on this Mac…"
                let maximumFiles = Self.maximumIndexedFiles
                let maximumCharacters = Self.maximumIndexedCharacters
                task = Task.detached(priority: .utility) {
                    let startedAccess = resolution.url.startAccessingSecurityScopedResource()
                    defer {
                        if startedAccess { resolution.url.stopAccessingSecurityScopedResource() }
                    }
                    return try Self.scan(
                        folderURL: resolution.url,
                        maximumFiles: maximumFiles,
                        maximumCharacters: maximumCharacters
                    )
                }
                indexingTask = task
            } catch {
                errorMessage = error.localizedDescription
                status = "Choose the folder again to restore access."
                return
            }
        }

        do {
            let result = try await task.value
            guard indexingID == taskID else { return }
            indexedFiles = result.files
            indexedFileCount = result.files.count
            hasCompletedIndex = true
            lastIndexedAt = Date()
            errorMessage = nil
            if result.reachedLimit {
                status = "Indexed \(result.files.count) documents; the local index limit was reached. Choose a smaller folder for complete coverage."
            } else if result.files.isEmpty {
                status = "No supported readable documents were found in this folder."
            } else {
                let skipped = result.skippedCount == 0 ? "" : " Skipped \(result.skippedCount) unreadable or oversized files."
                status = "Indexed \(result.files.count) documents locally.\(skipped)"
            }
        } catch {
            guard indexingID == taskID else { return }
            errorMessage = error.localizedDescription
            status = "Folder indexing failed. Choose the folder again or try a smaller folder."
        }

        if indexingID == taskID {
            indexingTask = nil
            indexingID = nil
            isIndexing = false
        }
    }

    private func cancelIndexingAndClearCache() {
        indexingTask?.cancel()
        indexingTask = nil
        indexingID = nil
        isIndexing = false
        indexedFiles = []
        indexedFileCount = 0
        hasCompletedIndex = false
        lastIndexedAt = nil
    }

    private static func makeBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return try url.bookmarkData()
        }
    }

    private static func resolveBookmark(_ bookmark: Data) throws -> (url: URL, isStale: Bool) {
        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }
        return (url, isStale)
    }

    nonisolated private static func scan(
        folderURL: URL,
        maximumFiles: Int,
        maximumCharacters: Int
    ) throws -> ScanResult {
        let folderValues = try folderURL.resourceValues(forKeys: [.isDirectoryKey])
        guard folderValues.isDirectory == true else { throw FolderLibraryError.folderUnavailable }

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
            .isPackageKey, .fileSizeKey
        ]
        let excludedDirectoryNames: Set<String> = [
            "Library", "Applications", "System", "private", "dev", "Volumes",
            ".Trash", "node_modules", ".git", "DerivedData", "Pods", ".build"
        ]
        let rootPath = folderURL.standardizedFileURL.path
        let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        )

        var files: [VeritySharedConversationFile] = []
        var skippedCount = 0
        var indexedCharacters = 0
        var reachedLimit = false
        let supported = VerityNovaClient.supportedExtensions

        while let url = enumerator?.nextObject() as? URL {
            if Task.isCancelled { throw CancellationError() }
            guard let values = try? url.resourceValues(forKeys: keys) else {
                skippedCount += 1
                continue
            }

            if values.isDirectory == true {
                let path = url.standardizedFileURL.path
                if path != rootPath && excludedDirectoryNames.contains(url.lastPathComponent) {
                    enumerator?.skipDescendants()
                }
                continue
            }

            guard values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  supported.contains(url.pathExtension.lowercased()) else { continue }
            guard (values.fileSize ?? 0) <= 50 * 1024 * 1024 else {
                skippedCount += 1
                continue
            }
            guard files.count < maximumFiles,
                  indexedCharacters < maximumCharacters else {
                reachedLimit = true
                break
            }

            do {
                let extracted = try VerityNovaClient.conversationSources(from: url)
                var boundedSources: [VerityDocumentSource] = []
                for source in extracted {
                    let available = maximumCharacters - indexedCharacters
                    guard available > 0 else { break }
                    let excerpt = String(source.excerpt.prefix(available))
                    guard !excerpt.isEmpty else { continue }
                    boundedSources.append(VerityDocumentSource(id: source.id, title: source.title, excerpt: excerpt))
                    indexedCharacters += excerpt.count
                }
                guard !boundedSources.isEmpty else { continue }
                files.append(VeritySharedConversationFile(
                    path: url.standardizedFileURL.path,
                    name: url.lastPathComponent,
                    sources: boundedSources
                ))
                if indexedCharacters >= maximumCharacters {
                    reachedLimit = true
                    break
                }
            } catch {
                skippedCount += 1
            }
        }

        return ScanResult(files: files, skippedCount: skippedCount, reachedLimit: reachedLimit)
    }
}

private enum FolderLibraryError: LocalizedError {
    case folderRequired
    case folderUnavailable
    case permissionUnavailable

    var errorDescription: String? {
        switch self {
        case .folderRequired: return "Choose a folder to enable local file search."
        case .folderUnavailable: return "VERITY can't access that folder. Choose it again in Settings."
        case .permissionUnavailable: return "VERITY's saved folder permission is unavailable. Choose the folder again in Settings."
        }
    }
}
