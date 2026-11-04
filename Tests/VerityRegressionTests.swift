import Foundation
import Darwin

@main
struct VerityRegressionTests {
    static func main() throws {
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            guard condition() else {
                FileHandle.standardError.write(Data("FAIL: \(label)\n".utf8))
                exit(1)
            }
            print("PASS: \(label)")
        }

        let openAI = #"{"choices":[{"message":{"content":"Hello from Verity."}}]}"#.data(using: .utf8)!
        check(VerityResponseParser.assistantText(from: openAI) == "Hello from Verity.", "OpenAI-compatible document response")
        let generic = #"{"response":"A concise answer."}"#.data(using: .utf8)!
        check(VerityResponseParser.assistantText(from: generic) == "A concise answer.", "Generic JSON response")
        let blocks = #"{"content":[{"type":"text","text":"First paragraph."},{"type":"text","text":"Second paragraph."}]}"#.data(using: .utf8)!
        check(VerityResponseParser.assistantText(from: blocks) == "First paragraph.\nSecond paragraph.", "Content-block response")
        check(VerityResponseParser.assistantText(from: Data("Plain text answer".utf8)) == "Plain text answer", "Plain-text fallback")
        let delta = #"{"choices":[{"delta":{"content":"partial"}}]}"#.data(using: .utf8)!
        check(VerityResponseParser.streamDelta(from: delta) == "partial", "Streaming delta extraction")
        check(VerityResponseParser.containsSensitiveInformation("Remember that my password is hunter2"), "Sensitive phrase detection")
        check(VerityResponseParser.containsSensitiveInformation("token: abcdefghijklmnopqrstuvwxyz123456"), "Credential assignment detection")
        check(!VerityResponseParser.containsSensitiveInformation("I prefer a clean desktop and short answers."), "Normal memory remains allowed")

        check(VerityScreenSignals.containsExplicitText("This page is marked NSFW"), "Explicit screen text signal")
        check(VerityScreenSignals.containsExplicitText("Visit xvideos.com"), "Adult domain signal")
        check(!VerityScreenSignals.containsExplicitText("A normal research page about biology"), "Ordinary page is not flagged")
        check(!VerityScreenSignals.containsExplicitText("The XXXL shirt fits well"), "Keyword matching respects word boundaries")
        check(VerityScreenSignals.isBrowserBundle("com.google.Chrome"), "Chrome recognized as a supported browser")
        check(!VerityScreenSignals.isBrowserBundle("com.apple.finder"), "Finder is not treated as a browser")
        check(VerityScreenSignals.reaction(forApplication: "Minecraft") != nil, "Game app receives a scripted reaction")
        check(VerityScreenSignals.reaction(forApplication: "Finder") == nil, "Unrecognized apps are not spammed with reactions")

        check(VerityScreenSignals.isSchoolHours(weekday: 2, hour: 8, minute: 0), "School hours start at 08:00 on Monday")
        check(VerityScreenSignals.isSchoolHours(weekday: 6, hour: 15, minute: 29), "School hours include Friday 15:29")
        check(!VerityScreenSignals.isSchoolHours(weekday: 2, hour: 7, minute: 59), "School hours exclude times before 08:00")
        check(!VerityScreenSignals.isSchoolHours(weekday: 5, hour: 15, minute: 30), "School hours end at 15:30")
        check(!VerityScreenSignals.isSchoolHours(weekday: 7, hour: 12, minute: 0), "School hours exclude Saturday")
        check(!VerityScreenSignals.isSchoolHours(weekday: 1, hour: 9, minute: 0), "School hours exclude Sunday")
        check(VerityScreenSignals.isGamingApplication(appName: "Roblox", bundleID: "com.roblox.RobloxPlayer"), "Roblox app is recognized as a game")
        check(VerityScreenSignals.isGamingApplication(appName: "Steam", bundleID: "com.valvesoftware.steam"), "Steam app is recognized as a game")
        check(VerityScreenSignals.schoolHoursGamingTarget(
            appName: "Google Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "Play games on Poki",
            visibleText: "Poki games"
        ) == .browserSite("Poki"), "Poki is recognized in a supported browser")
        check(VerityScreenSignals.schoolHoursGamingTarget(
            appName: "Safari",
            bundleID: "com.apple.Safari",
            windowTitle: "CrazyGames - Play free online games",
            visibleText: ""
        ) == .browserSite("CrazyGames"), "CrazyGames is recognized in a supported browser")
        check(VerityScreenSignals.schoolHoursGamingTarget(
            appName: "Safari",
            bundleID: "com.apple.Safari",
            windowTitle: "Roblox",
            visibleText: "Discover experiences on Roblox"
        ) == .browserSite("Roblox"), "Roblox is recognized in a supported browser")
        check(VerityScreenSignals.schoolHoursGamingTarget(
            appName: "Google Chrome",
            bundleID: "com.google.Chrome",
            windowTitle: "School timetable",
            visibleText: "Today's lesson schedule"
        ) == nil, "Ordinary browser pages are not flagged as games")
        check(VerityScreenSignals.schoolHoursGamingTarget(
            appName: "Steam",
            bundleID: "com.valvesoftware.steam",
            windowTitle: "Library",
            visibleText: ""
        ) == .application("Steam"), "Steam is recognized as a foreground game application")

        let key = Data(repeating: 0x42, count: 32)
        let plaintext = Data("Verity's private memory archive".utf8)
        let envelope = try VerityMemoryCipher.seal(plaintext, keyData: key)
        check(VerityMemoryCipher.isEncrypted(envelope), "Encrypted archive marker")
        check(envelope != plaintext, "Archive is not stored as plaintext")
        let recovered = try VerityMemoryCipher.open(envelope, keyData: key)
        check(recovered == plaintext, "AES-GCM round trip")
        var tampered = envelope
        tampered[tampered.index(before: tampered.endIndex)] ^= 0x01
        var rejected = false
        do { _ = try VerityMemoryCipher.open(tampered, keyData: key) } catch { rejected = true }
        check(rejected, "AES-GCM rejects modified archive")
        print("All VERITY regression tests passed.")
    }
}
