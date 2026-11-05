import Foundation

private final class ReleaseFixtureProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recordedURLs: [URL] = []

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        recordedURLs = []
    }

    static func urls() -> [URL] {
        lock.lock(); defer { lock.unlock() }
        return recordedURLs
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        Self.lock.lock()
        Self.recordedURLs.append(url)
        Self.lock.unlock()
        let json = """
        {"tag_name":"v9.9.9","html_url":"https://github.com/Ethan-cat-a/Verity/releases/tag/v9.9.9","draft":false,"prerelease":false,"assets":[{"name":"VERITY-9.9.9-macOS.zip","browser_download_url":"https://github.com/Ethan-cat-a/Verity/releases/download/v9.9.9/VERITY-9.9.9-macOS.zip","digest":"sha256:0000000000000000000000000000000000000000000000000000000000000000"}]}
        """
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@main
struct VerityUpdateTests {
    @MainActor
    static func main() async throws {
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else {
                FileHandle.standardError.write(Data("FAIL: \(label)\n".utf8))
                exit(1)
            }
            print("PASS: \(label)")
        }

        let defaults = UserDefaults.standard
        let keys = ["verity.updates.automaticChecks", "verity.updates.automaticInstall", "verity.updates.lastChecked"]
        let previous = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        defaults.set(true, forKey: "verity.updates.automaticChecks")
        defaults.set(true, forKey: "verity.updates.automaticInstall")
        defaults.removeObject(forKey: "verity.updates.lastChecked")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReleaseFixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        ReleaseFixtureProtocol.reset()

        var declinedPrompts = 0
        let declined = VerityUpdateChecker(session: session, currentVersion: "1.2.1") { version, hasInstaller in
            declinedPrompts += 1
            return false
        }
        await declined.checkIfDue()
        check(declined.updateAvailable && declined.latestVersion == "9.9.9", "Automatic check detects an update")
        check(declinedPrompts == 1, "A detected update asks for approval")
        check(ReleaseFixtureProtocol.urls().count == 1 && !declined.isInstalling, "A legacy auto-install setting cannot bypass a declined prompt")
        await declined.checkNow()
        check(declinedPrompts == 1, "The same version does not repeatedly interrupt the user")

        let accepted = VerityUpdateChecker(session: session, currentVersion: "1.2.1") { _, _ in true }
        await accepted.checkNow()
        for _ in 0..<100 where !accepted.status.contains("couldn't finish") {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        check(accepted.status.contains("couldn't finish"), "Approving starts the installer and reports an unsupported test location")

        var unnecessaryPrompts = 0
        let current = VerityUpdateChecker(session: session, currentVersion: "9.9.9") { _, _ in
            unnecessaryPrompts += 1
            return true
        }
        await current.checkNow()
        check(!current.updateAvailable && unnecessaryPrompts == 0, "An up-to-date app does not ask to install")
        check(ReleaseFixtureProtocol.urls().allSatisfy { $0.host == "api.github.com" }, "Declining never downloads an update")
        print("All VERITY update approval tests passed.")
    }
}
