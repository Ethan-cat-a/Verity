import Foundation
import AppKit
import Combine

@MainActor
final class VerityUpdateChecker: ObservableObject {
    static let shared = VerityUpdateChecker()
    static let automaticChecksKey = "verity.updates.automaticChecks"
    private static let lastCheckKey = "verity.updates.lastChecked"
    private static let releaseAPI = URL(string: "https://api.github.com/repos/Ethan-cat-a/Verity/releases/latest")!

    @Published private(set) var isChecking = false
    @Published private(set) var updateAvailable = false
    @Published private(set) var latestVersion = ""
    @Published private(set) var status = "Updates have not been checked yet."
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var downloadURL: URL?
    @Published private(set) var releasePageURL: URL?

    private var automaticTask: Task<Void, Never>?

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
    }

    private init() {
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
        if let last, Date().timeIntervalSince(last) < 86_400 { return }
        await performCheck()
    }

    func checkNow() async {
        await performCheck()
    }

    private func performCheck() async {
        guard !isChecking else { return }
        isChecking = true
        status = "Checking GitHub Releases…"
        defer { isChecking = false }

        do {
            var request = URLRequest(url: Self.releaseAPI)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("VERITY-macOS", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw UpdateError.http(code)
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            guard !release.draft, !release.prerelease else {
                throw UpdateError.invalidRelease
            }
            guard let page = URL(string: release.html_url),
                  page.scheme == "https",
                  page.host == "github.com" else {
                throw UpdateError.invalidRelease
            }

            let version = release.tag_name.hasPrefix("v")
                ? String(release.tag_name.dropFirst())
                : release.tag_name
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.5.0"
            latestVersion = version
            releasePageURL = page
            updateAvailable = Self.isVersion(version, newerThan: current)

            let asset = release.assets.first(where: {
                $0.name.hasPrefix("VERITY-") && $0.name.hasSuffix("-macOS.dmg")
            })
            if let asset,
               let candidate = URL(string: asset.browser_download_url),
               candidate.scheme == "https",
               candidate.host == "github.com" {
                downloadURL = candidate
            } else {
                downloadURL = nil
            }

            if updateAvailable {
                status = downloadURL == nil
                    ? "VERITY \(version) is available on GitHub."
                    : "Update available · VERITY \(version)"
            } else {
                status = "You're up to date · VERITY \(current)"
            }
        } catch {
            status = "Update check failed · \(error.localizedDescription)"
        }

        let checked = Date()
        lastCheckedAt = checked
        UserDefaults.standard.set(checked, forKey: Self.lastCheckKey)
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

        var errorDescription: String? {
            switch self {
            case .http(let status): return "GitHub returned HTTP \(status)."
            case .invalidRelease: return "GitHub did not return a valid stable release."
            }
        }
    }
}
