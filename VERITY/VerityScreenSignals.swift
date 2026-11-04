import Foundation

/// Small, deterministic screen signals. These checks run on-device against OCR text
/// and the foreground app name; no screenshot is uploaded or retained.
enum VerityScreenSignals {
    private static let explicitTerms = [
        "porn", "nsfw", "xvideos", "xnxx", "redtube", "hentai",
        "onlyfans", "adult videos", "explicit content", "xxx"
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

    static func reaction(forApplication appName: String) -> String? {
        let name = appName.lowercased()
        let games = [
            "minecraft", "roblox", "fortnite", "valorant", "league of legends",
            "dota", "counter-strike", "counter strike", "cs2", "stardew valley",
            "terraria", "baldur", "hades", "overwatch", "genshin", "steam game"
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
