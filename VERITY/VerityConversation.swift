
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
        let use_speaker_boost: Bool
    }
}

struct VerityVoiceOption: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String

    static let defaultID = "QZ1okeFI43NQd6lXAzQ5"

    static let all: [VerityVoiceOption] = [
        VerityVoiceOption(id: defaultID, title: "Verity · Animated male", detail: "Youthful American male character voice with a warm mid-range, lively timing, clear diction, and a playful edge."),
        VerityVoiceOption(id: "iHiL14jSTiWXy4nzDtbq", title: "Bright cartoon (classic)", detail: "High-energy, playful character delivery"),
        VerityVoiceOption(id: "B6uUx2p7cRgxseOUyP6P", title: "Friendly young voice", detail: "Bright, conversational American character delivery"),
        VerityVoiceOption(id: "rLl4PSDTzX3VHL4wjSFI", title: "Warm animated companion", detail: "Natural, expressive male character delivery")
    ]
}

enum VerityVoiceService {
    static let voicePreferenceKey = "verity.voice.id"
    static let speedPreferenceKey = "verity.voice.speed"
    static let defaultVoiceID = VerityVoiceOption.defaultID

    static var voiceID: String {
        let saved = UserDefaults.standard.string(forKey: voicePreferenceKey)
        return saved == "iHiL14jSTiWXy4nzDtbq" ? defaultVoiceID : (saved ?? defaultVoiceID)
    }

    static var speed: Double {
        let stored = UserDefaults.standard.double(forKey: speedPreferenceKey)
        return stored == 0 ? 1.08 : min(1.20, max(0.85, stored))
    }

    static func synthesize(_ text: String, apiKey: String) async throws -> Data {
        let endpoint = "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)?output_format=mp3_44100_64"
        guard let url = URL(string: endpoint) else { throw VerityVoiceError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(ElevenLabsSpeechRequest(
            text: String(text.prefix(1800)),
            model_id: "eleven_v3",
            voice_settings: .init(stability: 0.38, similarity_boost: 0.82, style: 0.70, speed: speed, use_speaker_boost: true)
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
final class VerityConversationModel: ObservableObject {
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
    private var speechTask: Task<Void, Never>?
    private var speechGeneration = 0
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var shouldSubmitFinalTranscript = false
    private var hasHandledFinalTranscript = false
    private let nova = VerityNovaClient()

    init() { refreshVoiceStatus() }

    func refreshVoiceStatus() {
        do {
            let configured = try VerityKeychain.readElevenLabsAPIKey()?.isEmpty == false
            voiceStatus = configured ? "Verity character voice" : "Mac voice · Add an ElevenLabs key in Settings"
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
                messages.append(VerityConversationMessage(isUser: false, text: "I can remember project notes and preferences, but I won't store passwords, codes, payment details, or keys."))
                return
            }
            let category: VerityMemoryCategory = (lower.contains("prefer") || lower.contains("favorite") || lower.contains("favourite") || lower.contains("like ")) ? .preference : ((lower.contains("project") || lower.contains("working on") || lower.contains("building")) ? .project : .general)
            let title = String(remembered.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
            VerityMemoryStore.shared.saveMemory(title: title, content: remembered, category: category)
            let confirmation = VerityMemoryStore.shared.storageError == nil
                ? "Got it. I've saved that in my memory. You can review or remove it any time."
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
            let history = self.messages.suffix(8).map {
                VerityChatTurn(role: $0.isUser ? "user" : "assistant", content: String($0.text.prefix(3_500)))
            }
            let savedContext = VerityMemoryStore.shared.context(for: text)
            do {
                let reply = try await self.nova.conversationReply(
                    history: Array(history),
                    additionalContext: savedContext,
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
            messages.append(VerityConversationMessage(isUser: false, text: "Welcome back! Here's where we left off:\n\(summary)"))
        } else {
            messages.append(VerityConversationMessage(isUser: false, text: "Welcome back! I restored our last conversation."))
        }
    }

    func reactAfterBeingDragged() {
        guard !isListening && !isSending && !isSpeaking else { return }
        let lines = [
            "PUT ME DOWN. I WAS ROLLING WITH PURPOSE.",
            "EXCUSE YOU? I HAVE LEGS. WELL, ROTATION.",
            "I WAS BUSY BEING A SPHERE. LET ME LIVE.",
            "WHY WOULD YOU PICK UP A PERFECTLY GOOD BALL?",
            "I'M REPORTING THIS TO THE CIRCLE COUNCIL."
        ]
        let line = lines.randomElement() ?? "HEY. RUDE."
        VerityModel.shared.setStatus(line)
        startSpeaking(line, reaction: .angry)
    }

    private func reactionFor(input: String, reply: String) -> VerityMood? {
        let prompt = input.lowercased()
        let answer = reply.lowercased()

        if prompt.contains("joke") || prompt.contains("fun fact") ||
            prompt.contains("make me laugh") || answer.contains("haha") ||
            answer.contains("lol") {
            return .manic
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
        audioPlayer?.stop()
        audioPlayer = nil
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
            if let apiKey = try VerityKeychain.readElevenLabsAPIKey(), !apiKey.isEmpty {
                let audio = try await VerityVoiceService.synthesize(text, apiKey: apiKey)
                guard !Task.isCancelled, generation == speechGeneration else { return }
                let player = try AVAudioPlayer(data: audio)
                audioPlayer = player
                player.prepareToPlay()
                guard player.play() else { throw VerityVoiceError.invalidResponse }
                while player.isPlaying && !Task.isCancelled && generation == speechGeneration {
                    try? await Task.sleep(nanoseconds: 80_000_000)
                }
            } else {
                voiceStatus = "Mac voice · Add an ElevenLabs key in Settings"
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.04
                utterance.pitchMultiplier = 1.10
                speechSynthesizer.speak(utterance)
                while speechSynthesizer.isSpeaking && !Task.isCancelled && generation == speechGeneration {
                    try? await Task.sleep(nanoseconds: 80_000_000)
                }
            }
        } catch {
            guard !Task.isCancelled, generation == speechGeneration else { return }
            voiceStatus = "Using Mac voice · character voice service unavailable"
            errorMessage = error.localizedDescription
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            speechSynthesizer.speak(utterance)
            while speechSynthesizer.isSpeaking && !Task.isCancelled && generation == speechGeneration {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }


    func stopSpeaking() {
        speechGeneration += 1
        speechTask?.cancel()
        speechTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        VerityModel.shared.setMood(.happy)
    }
}

@MainActor
private enum VerityScriptedReplies {
    static func reply(for rawText: String) -> String? {
        let text = rawText.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "!?., "))
        if ["hi", "hey", "hello", "yo", "hiya"].contains(text) || text.hasPrefix("hello ") || text.hasPrefix("hey ") {
            return ["Hey! I'm right here. What's up?", "Hiiii! Good to see you.", "Hello, friend! What are we getting into today?"].randomElement()
        }
        if text.contains("good morning") { return "Good morning! I hope today's treating you nicely. What should we tackle first?" }
        if text.contains("good night") || text == "goodnight" { return "Good night! I'll be right here when you need me." }
        if text.contains("thank") { return "You're very welcome! That's what I'm here for." }
        if text == "who are you" || text.contains("what are you") {
            return "I'm Verity, your little desktop companion. I can chat, understand documents, and help you work through things on your Mac."
        }
        if text.contains("what can you do") || text == "help" {
            return "I can chat, answer questions, read supported documents, summarize files, pull out key points, and keep safe copies in my Vault. Talk to me or drop a file on my ball."
        }
        if text.contains("tell me a joke") || text == "joke" || text.contains("make me laugh") {
            return "Why did the computer go to the doctor? It had a virus. I know, I know… I'm working on my comedy."
        }
        if text.contains("fun fact") {
            return "Here's a fun fact: octopuses have three hearts, and two of them stop beating when they swim. I think that makes me a very efficient ball."
        }
        if text == "dance" || text.contains("do a dance") {
            VerityModel.shared.setMood(.excited)
            return "Tiny victory dance! Wobble, wobble, wobble. Nailed it."
        }
        if text == "bye" || text == "goodbye" || text == "see you" {
            return "Bye for now! Don't forget to feed me a document sometime."
        }
        return nil
    }
}

struct VerityConversationView: View {
    @ObservedObject var model: VerityConversationModel
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
                VerityFace(size: 48, mood: VerityModel.shared.mood)
                    .shadow(color: .orange.opacity(0.16), radius: 7, y: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Talk with Verity").font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(model.isListening ? "I'm listening…" : model.isSpeaking ? "Verity is talking…" : model.voiceStatus)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { model.saveCurrentSession() } label: {
                    Image(systemName: "bookmark").font(.system(size: 12, weight: .semibold)).frame(width: 27, height: 27)
                }
                .buttonStyle(.plain)
                .help("Save this session")
                .disabled(model.messages.isEmpty)

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
                            Text("Hey! I'm Verity.").font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("Tap the microphone, say something, then tap again when you're finished. Or type a message below. I can also read files you drop on my ball.")
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    quickAction("Tell me a joke", prompt: "Tell me a joke")
                    quickAction("Fun fact", prompt: "Tell me a fun fact")
                    quickAction("What can you do?", prompt: "What can you do?")
                }
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

    private func quickAction(_ title: String, prompt: String) -> some View {
        Button(title) { model.send(prompt) }.buttonStyle(.bordered).controlSize(.small)
    }

    private func sendDraft() {
        let text = draft
        draft = ""
        model.send(text)
    }
}
