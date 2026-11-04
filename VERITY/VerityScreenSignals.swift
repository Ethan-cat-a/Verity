import Foundation

/// Small, deterministic screen signals. These checks run on-device against OCR text
/// and the foreground app name; no screenshot is uploaded or retained.
enum VerityScreenSignals {
    enum GamingTarget: Equatable {
        case browserSite(String)
        case application(String)
    }

    private static let explicitTerms = [
        "porn", "nsfw", "xvideos", "xnxx", "redtube", "hentai",
        "onlyfans", "adult videos", "explicit content", "xxx"
    ]

    private static let gameApplicationNames = [
        "minecraft", "roblox", "fortnite", "valorant", "league of legends",
        "dota 2", "counter-strike", "counter strike", "cs2", "stardew valley",
        "terraria", "baldur's gate", "hades", "overwatch", "genshin impact",
        "steam"
    ]

    static func containsExplicitText(_ text: String) -> Bool {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return explicitTerms.contains { term in
            let escaped = NSRegularExpression.escapedPattern(for: term)
            let pattern = term.contains(" ")
                ? escaped
                : "(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])"
            return normalized.range(of: pattern, options: .regularExpression) != nil
        }
    }

    static func isBrowserBundle(_ bundleID: String) -> Bool {
        let browsers: Set<String> = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.google.Chrome.beta",
            "com.google.Chrome.dev",
            "org.mozilla.firefox",
            "company.thebrowser.Browser",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "com.operasoftware.Opera"
        ]
        return browsers.contains(bundleID)
    }

    /// School hours are weekdays, 08:00 inclusive through 15:30 exclusive.
    /// The caller supplies components from the Mac's current local calendar.
    static func isSchoolHours(weekday: Int, hour: Int, minute: Int) -> Bool {
        guard (2...6).contains(weekday), (0...23).contains(hour), (0...59).contains(minute) else {
            return false
        }
        let afterStart = hour > 8 || (hour == 8 && minute >= 0)
        let beforeEnd = hour < 15 || (hour == 15 && minute < 30)
        return afterStart && beforeEnd
    }

    static func isGamingApplication(appName: String, bundleID: String) -> Bool {
        let name = appName.lowercased()
        let identifier = bundleID.lowercased()
        if identifier == "com.valvesoftware.steam" ||
            identifier.hasPrefix("com.roblox.") ||
            name.contains("roblox") {
            return true
        }
        return gameApplicationNames.contains { name.contains($0) }
    }

    /// Identifies known game sites in supported browsers, or known game apps.
    /// Browser recognition uses the window title plus locally recognized visible text.
    static func schoolHoursGamingTarget(
        appName: String,
        bundleID: String,
        windowTitle: String,
        visibleText: String
    ) -> GamingTarget? {
        if isBrowserBundle(bundleID) {
            let pageText = windowTitle + " " + visibleText
            if containsGamingBrand("crazygames", in: pageText) ||
                pageText.localizedCaseInsensitiveContains("crazygames.com") {
                return .browserSite("CrazyGames")
            }
            if containsGamingBrand("poki", in: pageText) ||
                pageText.localizedCaseInsensitiveContains("poki.com") {
                return .browserSite("Poki")
            }
            if containsGamingBrand("roblox", in: pageText) ||
                pageText.localizedCaseInsensitiveContains("roblox.com") {
                return .browserSite("Roblox")
            }
            return nil
        }

        if isGamingApplication(appName: appName, bundleID: bundleID) {
            return .application(appName)
        }
        return nil
    }

    private static func containsGamingBrand(_ brand: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: brand)
        let pattern = "(?<![A-Za-z0-9])\(escaped)(?![A-Za-z0-9])"
        return text.range(of: pattern, options: .regularExpression.union(.caseInsensitive)) != nil
    }

    static func reaction(forApplication appName: String) -> String? {
        let name = appName.lowercased()
        let games = [
            "minecraft", "roblox", "fortnite", "valorant", "league of legends",
            "dota", "counter-strike", "counter strike", "cs2", "stardew valley",
            "terraria", "baldur", "hades", "overwatch", "genshin", "steam game", "steam"
        ]
        if games.contains(where: { name.contains($0) }) {
            return "Gaming again? I suppose even geniuses need to watch someone else win."
        }

        let coding = ["xcode", "visual studio code", "cursor", "terminal", "intellij", "pycharm"]
        if coding.contains(where: { name.contains($0) }) {
            return "Writing code? Do try to keep up. I have already spotted three ways to improve it."
        }

        let browsers = ["safari", "google chrome", "firefox", "arc", "microsoft edge", "brave"]
        if browsers.contains(where: { name.contains($0) }) {
            return "Research mode? Excellent. Bring me something I don't already know."
        }

        let creative = ["figma", "photoshop", "illustrator", "final cut", "premiere"]
        if creative.contains(where: { name.contains($0) }) {
            return "Making something? At last, a worthy use of the pixels."
        }

        return nil
    }
}
