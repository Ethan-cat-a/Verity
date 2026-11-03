import SwiftUI
import AVFoundation

/// The small set of controls that matter for the VERITY companion.
struct VeritySettingsView: View {
    @State private var connectionStatus = "Checking connection…"
    @State private var isConnected = false
    @State private var isChecking = false
    @State private var elevenLabsKey = ""
    @State private var hasSavedElevenLabsKey = false
    @State private var voiceMessage = ""
    @State private var previewPlayer: AVAudioPlayer?
    @AppStorage(VerityVoiceService.voicePreferenceKey) private var selectedVoiceID = VerityVoiceService.defaultVoiceID
    @AppStorage(VerityCharacterPreferences.eerieIdleEnabledKey) private var eerieIdleEnabled = true
    @AppStorage(VerityVoiceService.useElevenLabsPreferenceKey) private var useElevenLabsVoice = false
    @AppStorage(VerityMemoryStore.enabledKey) private var memoryEnabled = true
    @State private var memoryMessage = ""
    @AppStorage(VerityUpdateChecker.automaticChecksKey) private var automaticUpdateChecks = true
    @AppStorage(VerityUpdateChecker.automaticInstallKey) private var automaticUpdateInstall = true
    @ObservedObject private var updateChecker = VerityUpdateChecker.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.10.0"
    }

    var body: some View {
        Form {
            Section("The character") {
                Toggle("Occasional unsettling stare", isOn: $eerieIdleEnabled)
                Text("Once in a while, Verity drops the smile and holds a strange stare for a few seconds. No screen watching, no background monitoring.")
                    .font(.caption).foregroundStyle(.secondary)
                Label("A know-it-all ball with a big ego. Usually helpful. Occasionally odd.", systemImage: "face.smiling")
                    .font(.callout)
            }

            Section("Voice") {
                Picker("Voice", selection: $selectedVoiceID) {
                    ForEach(VerityVoiceOption.all) { voice in
                        Text(voice.title).tag(voice.id)
                    }
                }
                Toggle("Use ElevenLabs voice (adds synthesis time)", isOn: $useElevenLabsVoice)
                    .disabled(!hasSavedElevenLabsKey)
                HStack(spacing: 8) {
                    Image(systemName: hasSavedElevenLabsKey ? "checkmark.circle.fill" : "waveform")
                        .foregroundStyle(hasSavedElevenLabsKey ? .green : .secondary)
                    Text(hasSavedElevenLabsKey && useElevenLabsVoice ? "Character voice enabled" : "Using the fast built-in Mac voice")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Preview") { Task { await previewSelectedVoice() } }
                        .disabled(!hasSavedElevenLabsKey)
                }
                SecureField("ElevenLabs API key", text: $elevenLabsKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save key") { saveElevenLabsKey() }
                        .disabled(elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasSavedElevenLabsKey {
                        Button("Remove", role: .destructive) { removeElevenLabsKey() }
                    }
                    Spacer()
                    Link("Get API key", destination: URL(string: "https://elevenlabs.io/app/settings/api-keys")!)
                        .font(.caption)
                }
                if !voiceMessage.isEmpty {
                    Text(voiceMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Text("The key is stored in macOS Keychain. Without it, Verity uses the built-in Mac voice for the fastest response.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Memory") {
                Toggle("Use things I explicitly asked you to remember", isOn: $memoryEnabled)
                Button("Clear saved memories", role: .destructive) {
                    VerityMemoryStore.shared.clearMemories()
                    memoryMessage = "Saved memories cleared."
                }
                if !memoryMessage.isEmpty {
                    Text(memoryMessage).font(.caption).foregroundStyle(.secondary)
                }
                Text("Verity only saves a note when you say “remember that…”.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Connection") {
                HStack(spacing: 8) {
                    Circle().fill(isConnected ? Color.green : Color.orange).frame(width: 8, height: 8)
                    Text(connectionStatus).font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button(isChecking ? "Checking…" : "Test") { Task { await checkConnection() } }
                        .disabled(isChecking)
                }
            }

            Section("Updates") {
                Toggle("Check automatically", isOn: $automaticUpdateChecks)
                Toggle("Download and install automatically", isOn: $automaticUpdateInstall)
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(updateChecker.status).font(.system(size: 12, weight: .medium))
                        if let checked = updateChecker.lastCheckedAt {
                            Text("Last checked " + checked.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Check now") { Task { await updateChecker.checkNow() } }
                        .disabled(updateChecker.isChecking)
                }
                if updateChecker.updateAvailable {
                    Button {
                        Task { await updateChecker.installAvailableUpdate() }
                    } label: {
                        Label("Install VERITY \(updateChecker.latestVersion)", systemImage: "arrow.down.circle")
                    }
                    .disabled(updateChecker.isInstalling)
                    Button("Open download page") { updateChecker.openDownload() }
                        .disabled(updateChecker.isInstalling)
                }
            }

            Section("About") {
                LabeledContent("VERITY", value: appVersion)
                Text("The know-it-all ball. Big ego, fast answers, and a slightly unsettling side.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(14)
        .frame(width: 500, height: 560)
        .navigationTitle("VERITY")
        .task {
            VerityVoiceService.migrateLegacyVoicePreferenceIfNeeded()
            selectedVoiceID = UserDefaults.standard.string(forKey: VerityVoiceService.voicePreferenceKey)
                ?? VerityVoiceService.defaultVoiceID
            UserDefaults.standard.register(defaults: [VerityUpdateChecker.automaticChecksKey: true])
            refreshVoiceKeyStatus()
            await checkConnection()
            if automaticUpdateChecks { updateChecker.startAutomaticChecks() }
        }
        .onDisappear { previewPlayer?.stop() }
        .onChange(of: automaticUpdateChecks) { enabled in
            if enabled { updateChecker.startAutomaticChecks() }
            else { updateChecker.stopAutomaticChecks() }
        }
        .onChange(of: automaticUpdateInstall) { enabled in
            if enabled && updateChecker.updateAvailable {
                Task { await updateChecker.installAvailableUpdate() }
            }
        }
    }

    private func refreshVoiceKeyStatus() {
        do {
            hasSavedElevenLabsKey = try VerityKeychain.readElevenLabsAPIKey()?.isEmpty == false
        } catch {
            hasSavedElevenLabsKey = false
            voiceMessage = error.localizedDescription
        }
    }

    @MainActor
    private func previewSelectedVoice() async {
        do {
            guard let apiKey = try VerityKeychain.readElevenLabsAPIKey(), !apiKey.isEmpty else {
                voiceMessage = "Add an ElevenLabs API key before previewing."
                return
            }
            let sample = "I'm Verity. The smartest ball on your desktop. Ask me anything; I already know."
            let audio = try await VerityVoiceService.synthesize(sample, apiKey: apiKey)
            previewPlayer?.stop()
            let player = try AVAudioPlayer(data: audio)
            previewPlayer = player
            player.prepareToPlay()
            guard player.play() else { throw VerityVoiceError.invalidResponse }
            voiceMessage = "Playing Verity."
        } catch {
            voiceMessage = "Voice preview failed: \(error.localizedDescription)"
        }
    }

    private func saveElevenLabsKey() {
        do {
            try VerityKeychain.saveElevenLabsAPIKey(elevenLabsKey)
            elevenLabsKey = ""
            hasSavedElevenLabsKey = true
            voiceMessage = "Voice key saved securely."
        } catch {
            voiceMessage = "Couldn't save the key: \(error.localizedDescription)"
        }
    }

    private func removeElevenLabsKey() {
        do {
            try VerityKeychain.deleteElevenLabsAPIKey()
            elevenLabsKey = ""
            hasSavedElevenLabsKey = false
            voiceMessage = "Voice key removed. Verity will use the Mac voice."
        } catch {
            voiceMessage = "Couldn't remove the key: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func checkConnection() async {
        isChecking = true
        defer { isChecking = false }
        do {
            let health = try await VerityNovaClient().healthCheck()
            if health.ok == true && health.keyConfigured == true {
                isConnected = true
                connectionStatus = "Connected"
            } else if health.ok == true {
                isConnected = false
                connectionStatus = "Online · service key needs attention"
            } else {
                isConnected = false
                connectionStatus = "Connection needs attention"
            }
        } catch {
            isConnected = false
            connectionStatus = "Connection unavailable"
        }
    }
}
