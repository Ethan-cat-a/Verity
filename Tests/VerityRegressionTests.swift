import Foundation
import Darwin

@main
struct VerityRegressionTests {
    @MainActor
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
        let streamedChunks = ["Hello", " world", " ", "again.", "\n", "    print(1)", "\n"]
        let streamedAnswer = try streamedChunks.map { chunk in
            let data = try JSONSerialization.data(withJSONObject: ["choices": [["delta": ["content": chunk]]]])
            return VerityResponseParser.streamDelta(from: data)
        }.joined()
        check(streamedAnswer == streamedChunks.joined(), "Stream preserves spaces, newlines and code indentation")
        let genericDelta = try JSONSerialization.data(withJSONObject: ["delta": ["text": " \n"]])
        check(VerityResponseParser.streamDelta(from: genericDelta) == " \n", "Whitespace-only generic delta")
        let blocksDelta = try JSONSerialization.data(withJSONObject: ["delta": ["content": [["text": " a"], ["text": " b"]]]])
        check(VerityResponseParser.streamDelta(from: blocksDelta) == " a b", "Streaming blocks concatenate without inserted separators")

        for prompt in ["Explain Thanksgiving", "Hey, help me debug this", "Hello can you solve 2+2",
                       "Thanks, now explain recursion", "What are you doing to solve this?",
                       "Tell me a joke about Swift", "Explain why people say good morning"] {
            check(VerityScriptedReplies.reply(for: prompt) == nil, "Substantive prompt reaches AI: \(prompt)")
        }
        for prompt in ["Hello!", "THANK YOU.", "good morning", "Who are you?", "tell me a joke"] {
            check(VerityScriptedReplies.reply(for: prompt) != nil, "Simple scripted prompt: \(prompt)")
        }

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
            windowTitle: "Crazy Games - Play free online games",
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
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let archiveURL = directory.appendingPathComponent("memory.json")
        let original = VerityMemoryStore(fileURL: archiveURL, readEncryptionKey: { key }, createEncryptionKey: { key })
        original.saveMemory(title: "Original", content: "Existing project notes", category: .project)
        original.saveSession(title: "Session", goal: "", nextStep: "", notes: "", messages: [VeritySavedMessage(isUser: true, text: "Existing session")])
        let originalBytes = try Data(contentsOf: archiveURL)
        var keyAvailable = false
        var createdKey = false
        let recovering = VerityMemoryStore(
            fileURL: archiveURL,
            readEncryptionKey: { keyAvailable ? key : nil },
            createEncryptionKey: { createdKey = true; return key }
        )
        check(recovering.storageError != nil, "Missing archive key reports load error")
        recovering.saveMemory(title: "New", content: "New notes", category: .general)
        recovering.saveSession(title: "New session", goal: "", nextStep: "", notes: "", messages: [VeritySavedMessage(isUser: true, text: "New message")])
        recovering.clearMemories()
        let bytesAfterBlockedWrites = try Data(contentsOf: archiveURL)
        check(bytesAfterBlockedWrites == originalBytes, "Failed load blocks writes and clears without changing archive")
        check(!createdKey && recovering.memories.isEmpty && recovering.sessions.isEmpty, "Blocked saves do not create a replacement key or mutate state")
        check(recovering.storageError != nil, "Blocked writes preserve load error")
        keyAvailable = true
        recovering.saveMemory(title: "Recovered", content: "Additional notes", category: .general)
        check(recovering.storageError == nil && recovering.memories.count == 2 && recovering.sessions.count == 1, "Key recovery reloads old archive before saving new memory")
        let reloaded = VerityMemoryStore(fileURL: archiveURL, readEncryptionKey: { key }, createEncryptionKey: { key })
        check(reloaded.memories.count == 2 && reloaded.sessions.count == 1, "Recovered save preserves old memories and sessions on disk")

        let corruptURL = directory.appendingPathComponent("corrupt.json")
        let corruptBytes = Data("not a valid archive".utf8)
        try corruptBytes.write(to: corruptURL)
        let corrupt = VerityMemoryStore(fileURL: corruptURL, readEncryptionKey: { key }, createEncryptionKey: { key })
        corrupt.saveMemory(title: "New", content: "Notes", category: .general)
        let afterCorruptSave = try Data(contentsOf: corruptURL)
        check(afterCorruptSave == corruptBytes && corrupt.storageError != nil, "Corrupt archive remains untouched after save attempt")
        print("All VERITY regression tests passed.")
    }
}
