import Foundation
import AppKit
import Combine
import CryptoKit

@MainActor
final class VerityUpdateChecker: ObservableObject {
    static let shared = VerityUpdateChecker()
    static let automaticChecksKey = "verity.updates.automaticChecks"
    private static let lastCheckKey = "verity.updates.lastChecked"
    private static let releaseAPI = URL(string: "https://api.github.com/repos/Ethan-cat-a/Verity/releases/latest")!
    private static let maximumInstallerSize: Int64 = 100 * 1_024 * 1_024

    @Published private(set) var isChecking = false
    @Published private(set) var isInstalling = false
    @Published private(set) var updateAvailable = false
    @Published private(set) var latestVersion = ""
    @Published private(set) var status = "Updates have not been checked yet."
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var downloadURL: URL?
    @Published private(set) var releasePageURL: URL?

    private var latestZipAsset: Asset?
    private var automaticTask: Task<Void, Never>?
    private var lastPromptedVersion: String?
    private let session: URLSession
    private let currentVersionOverride: String?
    private let promptHandler: ((String, Bool) -> Bool)?

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: String
        let digest: String?
    }

    init(
        session: URLSession = .shared,
        currentVersion: String? = nil,
        promptHandler: ((String, Bool) -> Bool)? = nil
    ) {
        self.session = session
        self.currentVersionOverride = currentVersion
        self.promptHandler = promptHandler
        UserDefaults.standard.register(defaults: [Self.automaticChecksKey: true])
        lastCheckedAt = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
    }

    func startAutomaticChecks() {
        guard automaticTask == nil else { return }
        automaticTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await checkIfDue()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 21_600_000_000_000)
                guard !Task.isCancelled else { break }
                await checkIfDue()
            }
        }
    }

    func stopAutomaticChecks() {
        automaticTask?.cancel()
        automaticTask = nil
    }

    func checkIfDue() async {
        guard UserDefaults.standard.bool(forKey: Self.automaticChecksKey) else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
        if let last, Date().timeIntervalSince(last) < 21_600 { return }
        await performCheck()
    }

    func checkNow() async {
        await performCheck()
    }

    func installAvailableUpdate() async {
        guard updateAvailable else { return }
        guard let asset = latestZipAsset else {
            status = "This release has no verified auto-update package. Opening the manual installer."
            openDownload()
            return
        }
        await downloadVerifyAndInstall(asset)
    }

    private func performCheck() async {
        guard !isChecking, !isInstalling else { return }
        isChecking = true
        status = "Checking GitHub Releases…"
        defer { isChecking = false }

        var successful = false
        do {
            var request = URLRequest(url: Self.releaseAPI)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("VERITY-macOS", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 20
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw UpdateError.http(code)
            }

            let release = try JSONDecoder().decode(Release.self, from: data)
            guard !release.draft, !release.prerelease else { throw UpdateError.invalidRelease }
            guard let page = URL(string: release.html_url),
                  page.scheme == "https",
                  page.host == "github.com" else {
                throw UpdateError.invalidRelease
            }

            let version = release.tag_name.hasPrefix("v")
                ? String(release.tag_name.dropFirst())
                : release.tag_name
            let current = currentVersionOverride ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.7.0")
            latestVersion = version
            releasePageURL = page
            updateAvailable = Self.isVersion(version, newerThan: current)

            let dmgName = "VERITY-\(version)-macOS.dmg"
            let zipName = "VERITY-\(version)-macOS.zip"
            let dmg = release.assets.first(where: { $0.name == dmgName })
            let zip = release.assets.first(where: { $0.name == zipName })
            downloadURL = Self.validGitHubAssetURL(dmg?.browser_download_url)
            latestZipAsset = zip

            if updateAvailable {
                status = "Update available · VERITY \(version)"
            } else {
                status = "You're up to date · VERITY \(current)"
            }
            successful = true
        } catch {
            status = "Update check failed · \(error.localizedDescription)"
        }

        if successful {
            let checked = Date()
            lastCheckedAt = checked
            UserDefaults.standard.set(checked, forKey: Self.lastCheckKey)
            if updateAvailable { promptForUpdateIfNeeded() }
        }
    }

    private func promptForUpdateIfNeeded() {
        guard !isInstalling, !latestVersion.isEmpty, lastPromptedVersion != latestVersion else { return }
        lastPromptedVersion = latestVersion
        let approved: Bool
        if let promptHandler {
            approved = promptHandler(latestVersion, latestZipAsset != nil)
        } else {
            let alert = NSAlert()
            alert.messageText = "VERITY \(latestVersion) is available"
            alert.informativeText = latestZipAsset == nil
                ? "A new version is available. Open its download page?"
                : "Install the update now? VERITY will verify the download and restart after installation."
            alert.addButton(withTitle: latestZipAsset == nil ? "Open Download Page" : "Install Update")
            alert.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            approved = alert.runModal() == .alertFirstButtonReturn
        }
        if approved {
            Task { await installAvailableUpdate() }
        }
    }

    private func downloadVerifyAndInstall(_ asset: Asset) async {
        guard !isInstalling else { return }
        isInstalling = true
        defer { isInstalling = false }

        do {
            guard let expectedDigest = asset.digest,
                  expectedDigest.hasPrefix("sha256:") else {
                throw UpdateError.missingDigest
            }
            guard let sourceURL = Self.validGitHubAssetURL(asset.browser_download_url),
                  asset.name == "VERITY-\(latestVersion)-macOS.zip" else {
                throw UpdateError.invalidAsset
            }

            let currentApp = try supportedInstallLocation()
            status = "Downloading VERITY \(latestVersion)…"

            var request = URLRequest(url: sourceURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            request.setValue("VERITY-macOS", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 120
            let (temporaryDownload, response) = try await session.download(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw UpdateError.downloadFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
            }

            let attributes = try FileManager.default.attributesOfItem(atPath: temporaryDownload.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard fileSize > 0, fileSize <= Self.maximumInstallerSize else {
                throw UpdateError.invalidInstallerSize
            }

            status = "Verifying update integrity…"
            let archiveData = try Data(contentsOf: temporaryDownload, options: [.mappedIfSafe])
            let actualDigest = SHA256.hash(data: archiveData)
                .map { String(format: "%02x", $0) }
                .joined()
            let expectedHex = String(expectedDigest.dropFirst("sha256:".count)).lowercased()
            guard expectedHex.count == 64, actualDigest == expectedHex else {
                throw UpdateError.checksumMismatch
            }

            let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let updateDirectory = cacheRoot
                .appendingPathComponent("com.verity.desktop", isDirectory: true)
                .appendingPathComponent("Updates", isDirectory: true)
                .appendingPathComponent(latestVersion, isDirectory: true)
            if FileManager.default.fileExists(atPath: updateDirectory.path) {
                try FileManager.default.removeItem(at: updateDirectory)
            }
            try FileManager.default.createDirectory(at: updateDirectory, withIntermediateDirectories: true)

            let archiveURL = updateDirectory.appendingPathComponent(asset.name)
            try FileManager.default.copyItem(at: temporaryDownload, to: archiveURL)

            let extractionDirectory = updateDirectory.appendingPathComponent("Extracted", isDirectory: true)
            try FileManager.default.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)
            status = "Preparing the verified update…"
            try Self.runTool("/usr/bin/ditto", arguments: [
                "-x", "-k", "--sequesterRsrc", archiveURL.path, extractionDirectory.path
            ])

            let stagedApp = extractionDirectory.appendingPathComponent("VERITY.app", isDirectory: true)
            guard FileManager.default.fileExists(atPath: stagedApp.path),
                  let stagedBundle = Bundle(url: stagedApp),
                  stagedBundle.bundleIdentifier == "com.verity.desktop",
                  stagedBundle.infoDictionary?["CFBundleShortVersionString"] as? String == latestVersion else {
                throw UpdateError.invalidBundle
            }

            try Self.runTool("/usr/bin/codesign", arguments: [
                "--verify", "--deep", "--strict", stagedApp.path
            ])

            status = "Installing VERITY \(latestVersion)…"
            try launchInstallerHelper(currentApp: currentApp, stagedApp: stagedApp, updateDirectory: updateDirectory)
            status = "VERITY \(latestVersion) is ready · restarting now…"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                NSApp.terminate(nil)
            }
        } catch {
            status = "Automatic update couldn't finish · \(error.localizedDescription)"
        }
    }

    private func supportedInstallLocation() throws -> URL {
        let appURL = Bundle.main.bundleURL.standardizedFileURL
        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL
        let allowedParents = [
            URL(fileURLWithPath: "/Applications", isDirectory: true).standardizedFileURL,
            homeApplications
        ]

        guard appURL.lastPathComponent == "VERITY.app",
              allowedParents.contains(appURL.deletingLastPathComponent().standardizedFileURL) else {
            throw UpdateError.unsupportedInstallLocation
        }
        let parent = appURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            throw UpdateError.installLocationNotWritable(parent.path)
        }
        return appURL
    }

    private func launchInstallerHelper(currentApp: URL, stagedApp: URL, updateDirectory: URL) throws {
        let logURL = updateDirectory.appendingPathComponent("installer.log")
        let script = """
        set -euo pipefail
        APP_PID="$1"
        CURRENT_APP="$2"
        STAGED_APP="$3"
        LOG_FILE="$4"
        exec >> "$LOG_FILE" 2>&1
        echo "VERITY updater started for PID $APP_PID"
        for attempt in {1..120}; do
            if ! /bin/kill -0 "$APP_PID" 2>/dev/null; then
                break
            fi
            /bin/sleep 0.25
        done
        if /bin/kill -0 "$APP_PID" 2>/dev/null; then
            echo "The running app did not exit; leaving the installed copy untouched."
            exit 1
        fi

        NEW_APP="$CURRENT_APP.verity-new-$APP_PID"
        BACKUP_APP="$CURRENT_APP.verity-backup-$APP_PID"
        APP_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$STAGED_APP/Contents/Info.plist")"
        NEW_PID=""
        recover_previous_app() {
            exit_code=$?
            if [ "$exit_code" -ne 0 ]; then
                echo "VERITY update failed; restoring the previous app."
                if [ -n "$NEW_PID" ] && /usr/bin/pgrep -x "$APP_EXECUTABLE" | /usr/bin/grep -qx "$NEW_PID"; then
                    /bin/kill "$NEW_PID" 2>/dev/null || true
                fi
                if [ -e "$BACKUP_APP" ]; then
                    if [ -e "$CURRENT_APP" ]; then /bin/rm -rf "$CURRENT_APP" || true; fi
                    /bin/mv "$BACKUP_APP" "$CURRENT_APP" || true
                fi
                if [ -e "$NEW_APP" ]; then /bin/rm -rf "$NEW_APP" || true; fi
                if [ -e "$CURRENT_APP" ]; then
                    /usr/bin/open -n "$CURRENT_APP" || true
                fi
            fi
        }
        trap recover_previous_app EXIT

        /usr/bin/ditto "$STAGED_APP" "$NEW_APP"
        /usr/bin/codesign --verify --deep --strict "$NEW_APP"
        # The verified app is the official release asset. Remove only its
        # download quarantine flag; never change Gatekeeper system-wide.
        /usr/bin/xattr -dr com.apple.quarantine "$NEW_APP" 2>/dev/null || true
        /bin/mv "$CURRENT_APP" "$BACKUP_APP"
        /bin/mv "$NEW_APP" "$CURRENT_APP"
        VERITY_PIDS_BEFORE=" $(/usr/bin/pgrep -x "$APP_EXECUTABLE" | /usr/bin/paste -sd ' ' - || true) "
        /usr/bin/open -n "$CURRENT_APP"
        launched=0
        for attempt in {1..40}; do
            NEW_PID=""
            for candidate in $(/usr/bin/pgrep -x "$APP_EXECUTABLE" || true); do
                case " $VERITY_PIDS_BEFORE " in
                    *" $candidate "*) continue ;;
                    *) NEW_PID="$candidate"; break ;;
                esac
            done
            if [ -n "$NEW_PID" ] && /bin/kill -0 "$NEW_PID" 2>/dev/null; then
                launched=1
                break
            fi
            /bin/sleep 0.5
        done
        if [ "$launched" -ne 1 ]; then
            echo "The updated app did not launch; rolling back."
            exit 1
        fi
        /bin/sleep 3
        if ! /bin/kill -0 "$NEW_PID" 2>/dev/null || ! /usr/bin/pgrep -x "$APP_EXECUTABLE" | /usr/bin/grep -qx "$NEW_PID"; then
            echo "The updated app exited during startup; rolling back."
            exit 1
        fi

        echo "VERITY update launched successfully; removing rollback copy."
        trap - EXIT
        /bin/rm -rf "$BACKUP_APP"
        """
        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        launcher.arguments = [
            "/bin/bash", "-c", script, "verity-updater",
            String(ProcessInfo.processInfo.processIdentifier),
            currentApp.path,
            stagedApp.path,
            logURL.path
        ]
        launcher.standardInput = FileHandle.nullDevice
        launcher.standardOutput = FileHandle.nullDevice
        launcher.standardError = FileHandle.nullDevice
        try launcher.run()
    }

    private static func runTool(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(data: outputData, encoding: .utf8) ?? "The command failed."
            throw UpdateError.commandFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func validGitHubAssetURL(_ rawValue: String?) -> URL? {
        guard let rawValue, let url = URL(string: rawValue),
              url.scheme == "https", url.host == "github.com" else { return nil }
        return url
    }

    func openDownload() {
        if let downloadURL {
            NSWorkspace.shared.open(downloadURL)
        } else if let releasePageURL {
            NSWorkspace.shared.open(releasePageURL)
        }
    }

    private static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private enum UpdateError: LocalizedError {
        case http(Int)
        case invalidRelease
        case invalidAsset
        case missingDigest
        case checksumMismatch
        case downloadFailed(Int)
        case invalidInstallerSize
        case invalidBundle
        case unsupportedInstallLocation
        case installLocationNotWritable(String)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .http(let status): return "GitHub returned HTTP \(status)."
            case .invalidRelease: return "GitHub did not return a valid stable release."
            case .invalidAsset: return "The release installer link is invalid."
            case .missingDigest: return "GitHub did not provide a SHA-256 digest for this installer."
            case .checksumMismatch: return "The downloaded installer failed its SHA-256 integrity check."
            case .downloadFailed(let status): return "Installer download failed with HTTP \(status)."
            case .invalidInstallerSize: return "The installer has an unexpected file size."
            case .invalidBundle: return "The downloaded app bundle did not match this VERITY release."
            case .unsupportedInstallLocation: return "Automatic updates work for VERITY.app installed directly in Applications."
            case .installLocationNotWritable(let path): return "VERITY cannot write to \(path). Move the app to a writable Applications folder to enable auto-install."
            case .commandFailed(let detail): return detail.isEmpty ? "The installer could not be unpacked or verified." : detail
            }
        }
    }
}
