
import SwiftUI
import AVFoundation
import Speech
import AppKit

struct VerityConversationMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

private struct ElevenLabsSpeechRequest: Encodable {
    let text: String
    let model_id: String
    let voice_settings: VoiceSettings

    struct VoiceSettings: Encodable {
        let stability: Double
        let similarity_boost: Double
        let style: Double
        let speed: Double
    }
}

private struct FishAudioSpeechRequest: Encodable {
    let text: String
    let reference_id: String
    let format = "mp3"
    let temperature = 0.7
    let top_p = 0.7
    let normalize = true
    let latency = "balanced"
    private let prosody = Prosody(speed: 0.96, volume: 0, normalize_loudness: true)

    private struct Prosody: Encodable {
        let speed: Double
        let volume: Double
        let normalize_loudness: Bool
    }
}

struct VerityVoiceOption: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String

    static let defaultID = "SkTrsOLN0P3ZmVSoI2k7"

    static let all: [VerityVoiceOption] = [
        VerityVoiceOption(
            id: defaultID,
            title: "Verity · Measured",
            detail: "A low, calm American voice with dry confidence and a quietly uncanny edge."
        ),
        VerityVoiceOption(
            id: "wWWn96OtTHu1sn8SRGEr",
            title: "Hale v3 · Expressive alternate",
            detail: "A more energetic, expressive male library voice."
        )
    ]
}

enum VerityVoiceService {
    static let voicePreferenceKey = "verity.voice.id"
    static let speedPreferenceKey = "verity.voice.speed"
    static let defaultVoiceID = VerityVoiceOption.defaultID
    static let previousDefaultVoiceID = "wWWn96OtTHu1sn8SRGEr"
    static let useElevenLabsPreferenceKey = "verity.voice.useElevenLabs"
    static let useFishAudioPreferenceKey = "verity.voice.useFishAudio"
    private static let voiceMigrationKey = "verity.voice.preference.migrated.1.2.0"

    static func migrateLegacyVoicePreferenceIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: voiceMigrationKey) else { return }

        let saved = defaults.string(forKey: voicePreferenceKey)
        let legacyIDs = [
            previousDefaultVoiceID,
            "QZ1okeFI43NQd6lXAzQ5",
            "iHiL14jSTiWXy4nzDtbq",
            "B6uUx2p7cRgxseOUyP6P",
            "rLl4PSDTzX3VHL4wjSFI"
        ]
        if let saved, legacyIDs.contains(saved) {
            defaults.set(defaultVoiceID, forKey: voicePreferenceKey)
        }
        defaults.set(true, forKey: voiceMigrationKey)
    }

    static var voiceID: String {
        migrateLegacyVoicePreferenceIfNeeded()
        return UserDefaults.standard.string(forKey: voicePreferenceKey) ?? defaultVoiceID
    }

    static func synthesize(
        _ text: String,
        apiKey: String,
        mood: VerityMood? = nil
    ) async throws -> Data {
        let endpoint = "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)?output_format=mp3_44100_64"
        guard let url = URL(string: endpoint) else { throw VerityVoiceError.invalidURL }

        let directedText = "[calm, low, measured, dryly amused] " + text
        let spokenText = String(directedText.prefix(1_760))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(ElevenLabsSpeechRequest(
            text: spokenText,
            model_id: "eleven_v4",
            voice_settings: .init(stability: 0.68, similarity_boost: 0.82, style: 0.18, speed: 0.90)
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw VerityVoiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "ElevenLabs returned HTTP \(http.statusCode)."
            throw VerityVoiceError.requestFailed(http.statusCode, detail)
        }
        guard !data.isEmpty else { throw VerityVoiceError.emptyAudio }
        return data
    }
}

enum FishAudioVoiceService {
    static let voiceModelID = "711cf3ed00ab441a8f54a45058047b7a"
    static let voiceModelURL = URL(string: "https://fish.audio/m/711cf3ed00ab441a8f54a45058047b7a/")!

    static func synthesize(_ text: String, apiKey: String) async throws -> Data {
        guard let url = URL(string: "https://api.fish.audio/v1/tts") else {
            throw FishAudioVoiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.setValue("drama-3", forHTTPHeaderField: "model")
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(FishAudioSpeechRequest(
            text: String(text.prefix(1_760)),
            reference_id: voiceModelID
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FishAudioVoiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "Fish Audio returned HTTP \(http.statusCode)."
            throw FishAudioVoiceError.requestFailed(http.statusCode, detail)
        }
        guard !data.isEmpty else { throw FishAudioVoiceError.emptyAudio }
        return data
    }
}

enum FishAudioVoiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(Int, String)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The Fish Audio voice URL is invalid."
        case .invalidResponse: return "Fish Audio returned an invalid response."
        case .requestFailed(let code, let detail): return "Fish Audio request failed (HTTP \(code)): \(detail.prefix(240))"
        case .emptyAudio: return "Fish Audio returned empty audio."
        }
    }
}

private enum VeritySpeechProvider: Sendable {
    case fishAudio(String)
    case elevenLabs(String)

    var status: String {
        switch self {
        case .fishAudio: return "VERITY community voice · Fish Audio"
        case .elevenLabs: return "VERITY character voice · Eleven v4"
        }
    }

    func synthesize(_ text: String, mood: VerityMood? = nil) async throws -> Data {
        switch self {
        case .fishAudio(let apiKey):
            return try await FishAudioVoiceService.synthesize(text, apiKey: apiKey)
        case .elevenLabs(let apiKey):
            return try await VerityVoiceService.synthesize(text, apiKey: apiKey, mood: mood)
        }
    }
}

enum VerityVoiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(Int, String)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The ElevenLabs voice URL is invalid."
        case .invalidResponse: return "ElevenLabs returned an invalid response."
        case .requestFailed(let code, let detail): return "ElevenLabs request failed (HTTP \(code)): \(detail.prefix(240))"
        case .emptyAudio: return "ElevenLabs returned empty audio."
        }
    }
}

@MainActor
final class VerityConversationModel: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    @Published var messages: [VerityConversationMessage] = []
    @Published var isListening = false
    @Published var isSending = false
    @Published var isSpeaking = false
    @Published var streamingReply = ""
    @Published var liveTranscript = ""
    @Published var errorMessage: String?
    @Published var voiceStatus = "Checking voice settings…"

    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var audioPlayback: (player: AVAudioPlayer, continuation: CheckedContinuation<Bool, Never>)?
    private var speechPlayback: (utterance: AVSpeechUtterance, continuation: CheckedContinuation<Void, Never>)?
    private var audioMeterTask: Task<Void, Never>?
    private var mouthAnimationTask: Task<Void, Never>?
    private var speechTask: Task<Void, Never>?
    private var pendingAudioTask: Task<Data, Error>?
    private var speechGeneration = 0
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var shouldSubmitFinalTranscript = false
    private var hasHandledFinalTranscript = false
    private let nova = VerityNovaClient()

    override init() {
        super.init()
        speechSynthesizer.delegate = self
        refreshVoiceStatus()
    }

    func refreshVoiceStatus() {
        do {
            let defaults = UserDefaults.standard
            let useFishAudio = defaults.bool(forKey: VerityVoiceService.useFishAudioPreferenceKey)
            let useElevenLabs = defaults.bool(forKey: VerityVoiceService.useElevenLabsPreferenceKey)
            let fishAudioConfigured = try VerityKeychain.readFishAudioAPIKey()?.isEmpty == false
            let elevenLabsConfigured = try VerityKeychain.readElevenLabsAPIKey()?.isEmpty == false
            if useFishAudio && fishAudioConfigured {
                voiceStatus = "VERITY community voice · Fish Audio"
            } else if useElevenLabs && elevenLabsConfigured {
                voiceStatus = "VERITY character voice · Eleven v4"
            } else {
                voiceStatus = "Mac voice · Fast mode"
            }
        } catch {
            voiceStatus = "Mac voice · Keychain unavailable"
        }
    }

    func toggleListening() {
        if isListening { finishListening() }
        else { Task { await beginListening() } }
    }

    private func beginListening() async {
        guard !isListening, !isSending else { return }
        errorMessage = nil
        liveTranscript = ""
        shouldSubmitFinalTranscript = false
        hasHandledFinalTranscript = false

        guard await requestSpeechPermissions() else {
            errorMessage = "Allow microphone and speech recognition access in System Settings → Privacy & Security, then try again."
            return
        }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available for your Mac's current language."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        recognitionRequest = request
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.liveTranscript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.handleFinalTranscript(self.liveTranscript)
                        return
                    }
                }
                if let error {
                    let transcript = self.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                    let shouldSubmit = self.shouldSubmitFinalTranscript
                    self.cleanUpRecognition(cancelTask: true)
                    if shouldSubmit && !transcript.isEmpty {
                        self.handleFinalTranscript(transcript)
                    } else if transcript.isEmpty {
                        self.errorMessage = "I didn't catch that. Try speaking a little closer to your microphone."
                    } else {
                        self.liveTranscript = transcript
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            voiceStatus = "Listening · tap the microphone to finish"
            VerityModel.shared.setMood(.listening)
        } catch {
            cleanUpRecognition(cancelTask: true)
            errorMessage = "Couldn't start the microphone: \(error.localizedDescription)"
            VerityModel.shared.setMood(.happy)
        }
    }

    private func requestSpeechPermissions() async -> Bool {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let speechAllowed: Bool
        switch speechStatus {
        case .authorized: speechAllowed = true
        case .notDetermined:
            speechAllowed = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default: speechAllowed = false
        }
        guard speechAllowed else { return false }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default: return false
        }
    }

    func finishListening() {
        guard isListening else { return }
        shouldSubmitFinalTranscript = true
        isListening = false
        audioEngine.stop()
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        voiceStatus = "Finishing transcription…"
        VerityModel.shared.setMood(.thinking)
    }

    func cancelListening() {
        shouldSubmitFinalTranscript = false
        cleanUpRecognition(cancelTask: true)
        isListening = false
        liveTranscript = ""
        VerityModel.shared.setMood(.happy)
    }

    private func cleanUpRecognition(cancelTask: Bool) {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
        if cancelTask { recognitionTask?.cancel() }
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
    }

    private func handleFinalTranscript(_ transcript: String) {
        guard !hasHandledFinalTranscript else { return }
        hasHandledFinalTranscript = true
        cleanUpRecognition(cancelTask: false)
        shouldSubmitFinalTranscript = false
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        liveTranscript = ""
        guard !cleaned.isEmpty else {
            errorMessage = "I didn't catch any words. Try again."
            VerityModel.shared.setMood(.happy)
            return
        }
        send(cleaned)
    }

    func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        if isSpeaking { stopSpeaking() }
        errorMessage = nil

        if let remembered = explicitRememberContent(from: text) {
            messages.append(VerityConversationMessage(isUser: true, text: text))
            if VerityResponseParser.containsSensitiveInformation(remembered) {
                messages.append(VerityConversationMessage(isUser: false, text: "I can store project notes and preferences. Passwords, codes, payment details, and keys are off-limits."))
                return
            }
            let lower = remembered.lowercased()
            let category: VerityMemoryCategory = (lower.contains("prefer") || lower.contains("favorite") || lower.contains("favourite") || lower.contains("like ")) ? .preference : ((lower.contains("project") || lower.contains("working on") || lower.contains("building")) ? .project : .general)
            let title = String(remembered.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
            VerityMemoryStore.shared.saveMemory(title: title, content: remembered, category: category)
            let confirmation = VerityMemoryStore.shared.storageError == nil
                ? "Saved. Naturally, I will remember."
                : "I tried to save that, but the local memory file reported an error: \(VerityMemoryStore.shared.storageError ?? "unknown error")"
            messages.append(VerityConversationMessage(isUser: false, text: confirmation))
            startSpeaking(confirmation)
            return
        }

        messages.append(VerityConversationMessage(isUser: true, text: text))
        VerityModel.shared.setMood(.thinking)

        if let scripted = VerityScriptedReplies.reply(for: text) {
            messages.append(VerityConversationMessage(isUser: false, text: scripted))
            let reaction = reactionFor(input: text, reply: scripted)
            startSpeaking(scripted, reaction: reaction)
            return
        }

        isSending = true
        streamingReply = ""
        Task { @MainActor [weak self] in
            guard let self else { return }
            let history = self.messages.suffix(4).map {
                VerityChatTurn(role: $0.isUser ? "user" : "assistant", content: String($0.text.prefix(1_200)))
            }
            let savedContext = String(VerityMemoryStore.shared.context(for: text).prefix(900))
            let uncannyAside = Int.random(in: 1...24) == 1
            do {
                let reply = try await self.nova.conversationReply(
                    history: Array(history),
                    additionalContext: savedContext,
                    uncannyAside: uncannyAside,
                    onTextChunk: { [weak self] chunk in
                        self?.streamingReply += chunk
                    }
                )
                self.streamingReply = ""
                self.messages.append(VerityConversationMessage(isUser: false, text: reply))
                self.isSending = false
                let reaction = self.reactionFor(input: text, reply: reply)
                self.startSpeaking(reply, reaction: reaction)
            } catch {
                self.streamingReply = ""
                self.isSending = false
                self.errorMessage = error.localizedDescription
                VerityModel.shared.showReaction(.shocked)
            }
        }
    }

    private func explicitRememberContent(from rawText: String) -> String? {
        let prefixes = ["remember that ", "remember this: ", "remember: ", "save this to memory: "]
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in prefixes {
            if trimmed.lowercased().hasPrefix(prefix) {
                let content = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return content.isEmpty ? nil : content
            }
        }
        return nil
    }

    func saveCurrentSession() {
        guard !messages.isEmpty else { return }
        let lastUserText = messages.last(where: { $0.isUser })?.text ?? "Verity conversation"
        let title = String(lastUserText.prefix(72))
        let goal = "Continue the conversation and work captured in this chat."
        let nextStep = "Pick up from the last exchange."
        let notes = messages.suffix(8).map { ($0.isUser ? "You: " : "Verity: ") + $0.text }.joined(separator: "\n")
        let savedMessages = messages.suffix(20).map { VeritySavedMessage(isUser: $0.isUser, text: $0.text) }
        VerityMemoryStore.shared.saveSession(title: title, goal: goal, nextStep: nextStep, notes: notes, messages: Array(savedMessages))
        VerityModel.shared.setStatus(VerityMemoryStore.shared.storageError == nil ? "Session saved. I'll keep our place." : "Couldn't save this session.")
    }

    func resumeSession(_ snapshot: VeritySessionSnapshot) {
        stopSpeaking()
        cancelListening()
        messages = snapshot.messages.map { VerityConversationMessage(isUser: $0.isUser, text: $0.text) }
        if !snapshot.goal.isEmpty || !snapshot.nextStep.isEmpty {
            let summary = [snapshot.goal, snapshot.nextStep].filter { !$0.isEmpty }.joined(separator: "\n")
            messages.append(VerityConversationMessage(isUser: false, text: "Back again. Here's the point we reached:\n\(summary)"))
        } else {
            messages.append(VerityConversationMessage(isUser: false, text: "Session restored. Continue."))
        }
    }

    func reactAfterBeingDragged() {
        guard !isListening && !isSending && !isSpeaking else { return }
        let lines = [
            "Hey! You can just click me whenever you need help.",
            "Need something? I'm right here!",
            "Ooh, what can I help you with?",
            "Here I am! Ask me anything.",
            "I'm your helper friend. What are we doing?"
        ]
        let line = lines.randomElement() ?? "Hi! What can I help you with?"
        VerityModel.shared.setStatus(line)
        startSpeaking(line, reaction: .angry)
    }

    private func reactionFor(input: String, reply: String) -> VerityMood? {
        let prompt = input.lowercased()
        let answer = reply.lowercased()

        if prompt.contains("joke") || prompt.contains("fun fact") ||
            prompt.contains("make me laugh") || answer.contains("haha") ||
            answer.contains("lol") {
            return nil
        }
        if prompt.contains("wrong") || prompt.contains("you suck") ||
            prompt.contains("angry") || prompt.contains("mad") {
            return .angry
        }
        if prompt.contains("really") || prompt.contains("are you sure") ||
            prompt.contains("prove it") || prompt.contains("sus") {
            return .suspicious
        }
        if answer.contains("i'm sorry") || answer.contains("i am sorry") ||
            answer.contains("something went wrong") {
            return .shocked
        }
        return nil
    }

    private func startSpeaking(_ text: String, reaction: VerityMood? = nil) {
        speechGeneration += 1
        let generation = speechGeneration
        speechTask?.cancel()
        pendingAudioTask?.cancel()
        pendingAudioTask = nil
        let previousAudioPlayer = audioPlayer
        finishAudioPlayback(successfully: false)
        previousAudioPlayer?.stop()
        audioPlayer = nil
        finishSpeechPlayback()
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechTask = Task { @MainActor [weak self] in
            await self?.speak(text, reaction: reaction, generation: generation)
        }
    }

    private func speak(_ text: String, reaction: VerityMood?, generation: Int) async {
        isSpeaking = true
        VerityModel.shared.setMood(.speaking)
        defer {
            if generation == speechGeneration {
                audioPlayer = nil
                audioMeterTask?.cancel()
                audioMeterTask = nil
                mouthAnimationTask?.cancel()
                mouthAnimationTask = nil
                VerityModel.shared.setSpeechLevel(0)
                pendingAudioTask?.cancel()
                pendingAudioTask = nil
                speechTask = nil
                isSpeaking = false
                if !Task.isCancelled {
                    if let reaction {
                        VerityModel.shared.showReaction(reaction)
                    } else {
                        VerityModel.shared.setMood(.happy)
                    }
                }
            }
        }

        do {
            let defaults = UserDefaults.standard
            let provider: VeritySpeechProvider?
            if defaults.bool(forKey: VerityVoiceService.useFishAudioPreferenceKey),
               let apiKey = try VerityKeychain.readFishAudioAPIKey(), !apiKey.isEmpty {
                provider = .fishAudio(apiKey)
            } else if defaults.bool(forKey: VerityVoiceService.useElevenLabsPreferenceKey),
                      let apiKey = try VerityKeychain.readElevenLabsAPIKey(), !apiKey.isEmpty {
                provider = .elevenLabs(apiKey)
            } else {
                provider = nil
            }

            if let provider {
                voiceStatus = provider.status
                let chunks = Self.makeSpeechChunks(text)
                guard let firstChunk = chunks.first else { throw VerityVoiceError.emptyAudio }

                pendingAudioTask = Task {
                    try await provider.synthesize(firstChunk)
                }

                for index in chunks.indices {
                    guard !Task.isCancelled, generation == speechGeneration,
                          let currentTask = pendingAudioTask else { return }

                    let audio = try await currentTask.value
                    guard !Task.isCancelled, generation == speechGeneration else { return }

                    // Start preparing the next phrase while the current phrase is playing.
                    if index + 1 < chunks.count {
                        let nextChunk = chunks[index + 1]
                        pendingAudioTask = Task {
                            try await provider.synthesize(nextChunk, mood: reaction)
                        }
                    } else {
                        pendingAudioTask = nil
                    }

                    let player = try AVAudioPlayer(data: audio)
                    guard await playAudio(player) else { throw VerityVoiceError.invalidResponse }
                }
            } else {
                voiceStatus = "Mac voice · Fast local speech"
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = Self.veritySystemVoice()
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.91
                utterance.pitchMultiplier = 0.88
                await speakLocally(utterance)
            }
        } catch {
            pendingAudioTask?.cancel()
            pendingAudioTask = nil
            guard !Task.isCancelled, generation == speechGeneration else { return }
            voiceStatus = "Using Mac voice · character voice service unavailable"
            errorMessage = error.localizedDescription
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = Self.veritySystemVoice()
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.91
            utterance.pitchMultiplier = 0.88
            await speakLocally(utterance)
        }
    }

    /// Wait for the audio engine's completion callback. Polling `isPlaying` directly
    /// can observe its initial false value before AVAudioPlayer starts the output.
    private func playAudio(_ player: AVAudioPlayer) async -> Bool {
        audioPlayer = player
        player.delegate = self
        player.isMeteringEnabled = true
        player.prepareToPlay()
        return await withCheckedContinuation { continuation in
            audioPlayback = (player, continuation)
            guard player.play() else {
                finishAudioPlayback(successfully: false)
                return
            }
            audioMeterTask?.cancel()
            audioMeterTask = Task { @MainActor [weak self, weak player] in
                guard let self, let player else { return }
                while !Task.isCancelled, self.audioPlayback?.player === player {
                    player.updateMeters()
                    let decibels = CGFloat(player.averagePower(forChannel: 0))
                    let level = min(max((decibels + 50) / 45, 0), 1)
                    VerityModel.shared.setSpeechLevel(level)
                    try? await Task.sleep(nanoseconds: 40_000_000)
                }
            }
        }
    }

    private func speakLocally(_ utterance: AVSpeechUtterance) async {
        await withCheckedContinuation { continuation in
            speechPlayback = (utterance, continuation)
            speechSynthesizer.speak(utterance)
        }
    }

    private func finishAudioPlayback(successfully: Bool) {
        guard let playback = audioPlayback else { return }
        audioPlayback = nil
        audioMeterTask?.cancel()
        audioMeterTask = nil
        VerityModel.shared.setSpeechLevel(0)
        if audioPlayer === playback.player { audioPlayer = nil }
        playback.continuation.resume(returning: successfully)
    }

    private func finishSpeechPlayback(for utterance: AVSpeechUtterance? = nil) {
        guard let playback = speechPlayback,
              utterance == nil || playback.utterance === utterance else { return }
        speechPlayback = nil
        mouthAnimationTask?.cancel()
        mouthAnimationTask = nil
        VerityModel.shared.setSpeechLevel(0)
        playback.continuation.resume()
    }

    private func animateMouth(for utterance: AVSpeechUtterance, range: NSRange) {
        guard speechPlayback?.utterance === utterance else { return }
        let source = utterance.speechString as NSString
        let safeRange = NSIntersectionRange(range, NSRange(location: 0, length: source.length))
        guard safeRange.length > 0 else { return }
        let spokenPart = source.substring(with: safeRange).lowercased()
        let pulseCount = max(1, min(5, spokenPart.filter { "aeiouy".contains($0) }.count))

        mouthAnimationTask?.cancel()
        mouthAnimationTask = Task { @MainActor [weak self] in
            for _ in 0..<pulseCount {
                guard let self, !Task.isCancelled,
                      self.speechPlayback?.utterance === utterance else { return }
                VerityModel.shared.setSpeechLevel(0.78)
                try? await Task.sleep(nanoseconds: 75_000_000)
                guard !Task.isCancelled else { return }
                VerityModel.shared.setSpeechLevel(0.12)
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard self?.audioPlayback?.player === player else { return }
            self?.finishAudioPlayback(successfully: flag)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard self?.audioPlayback?.player === player else { return }
            self?.finishAudioPlayback(successfully: false)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finishSpeechPlayback(for: utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finishSpeechPlayback(for: utterance) }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.animateMouth(for: utterance, range: characterRange)
        }
    }

    private static func makeSpeechChunks(_ text: String, maximumCharacters: Int = 320) -> [String] {
        let words = text.split(whereSeparator: \.isWhitespace)
        var chunks: [String] = []
        var current = ""

        for word in words {
            let addition = current.isEmpty ? String(word) : " " + word
            if !current.isEmpty && current.count + addition.count > maximumCharacters {
                chunks.append(current)
                current = String(word)
            } else {
                current += addition
            }

            if current.count >= 110, let last = current.last, ".!?;".contains(last) {
                chunks.append(current)
                current = ""
            }
        }

        if !current.isEmpty { chunks.append(current) }
        return chunks.isEmpty ? [text] : chunks
    }

    private static func veritySystemVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        return voices.first(where: {
            $0.language == "en-US" && $0.gender == .male && $0.quality == .enhanced
        }) ?? voices.first(where: {
            $0.language == "en-US" && $0.gender == .male
        }) ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    func stopSpeaking() {
        speechGeneration += 1
        speechTask?.cancel()
        speechTask = nil
        pendingAudioTask?.cancel()
        pendingAudioTask = nil
        let previousAudioPlayer = audioPlayer
        finishAudioPlayback(successfully: false)
        previousAudioPlayer?.stop()
        audioPlayer = nil
        finishSpeechPlayback()
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        VerityModel.shared.setMood(.happy)
    }
}

struct VerityConversationView: View {
    @ObservedObject var model: VerityConversationModel
    @ObservedObject private var characterModel = VerityModel.shared
    let onClose: () -> Void
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 9) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                VerityFace(size: 48, mood: characterModel.mood, speechLevel: characterModel.speechLevel)
                    .shadow(color: .orange.opacity(0.16), radius: 7, y: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("VERITY").font(.system(size: 15, weight: .black, design: .rounded)).tracking(1.2)
                    Text(model.isListening ? "I'm listening…" : model.isSpeaking ? "Verity is talking…" : model.voiceStatus)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if model.isSpeaking {
                    Button { model.stopSpeaking() } label: {
                        Image(systemName: "stop.fill").font(.system(size: 11, weight: .bold)).frame(width: 27, height: 27)
                    }
                    .buttonStyle(.plain).help("Stop speaking")
                }
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if model.messages.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Ask me anything. I already know.").font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("Or drop in a document. I will try not to make a big deal of it.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 15))
                    }
                    ForEach(model.messages) { message in
                        HStack {
                            if message.isUser { Spacer(minLength: 35) }
                            Text(message.text)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(message.isUser ? .white : .primary)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(message.isUser ? Color(red: 0.15, green: 0.16, blue: 0.18) : Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
                                .textSelection(.enabled)
                            if !message.isUser { Spacer(minLength: 35) }
                        }
                    }
                    if model.isListening && !model.liveTranscript.isEmpty {
                        Text(model.liveTranscript)
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }
                    if model.isSending && model.streamingReply.isEmpty {
                        HStack(spacing: 7) {
                            ProgressView().controlSize(.small)
                            Text("Thinking…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !model.streamingReply.isEmpty {
                        HStack {
                            Text(model.streamingReply)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
                                .textSelection(.enabled)
                            Spacer(minLength: 35)
                        }
                    }
                }
                .padding(.vertical, 3)
            }

            if let error = model.errorMessage {
                Text(error).font(.system(size: 10)).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }

            HStack(spacing: 8) {
                Button { model.toggleListening() } label: {
                    Image(systemName: model.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(model.isListening ? Color.red : Color.orange, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain).disabled(model.isSending)
                .help(model.isListening ? "Finish speaking" : "Talk to Verity")

                TextField("Message Verity…", text: $draft)
                    .textFieldStyle(.roundedBorder).lineLimit(1...3)
                    .onSubmit(sendDraft)
                    .disabled(model.isSending || model.isListening)

                Button(action: sendDraft) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 26)).foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSending)
            }
        }
        .padding(14)
        .frame(width: 380, height: 560)
        .background(.ultraThinMaterial)
        .onDisappear { model.cancelListening() }
    }


    private func sendDraft() {
        let text = draft
        draft = ""
        model.send(text)
    }
}
