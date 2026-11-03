
import SwiftUI
import AVFoundation

struct VeritySettingsView: View {
    @State private var connectionStatus = "Checking connection…"
    @State private var isConnected = false
    @State private var isChecking = false
    @State private var elevenLabsKey = ""
    @State private var hasSavedElevenLabsKey = false
    @State private var voiceMessage = ""
    @State private var previewPlayer: AVAudioPlayer?
    @AppStorage(VerityVoiceService.voicePreferenceKey) private var selectedVoiceID = VerityVoiceService.defaultVoiceID
    @AppStorage(VerityPetLifeModel.trashSnacksPreferenceKey) private var trashSnacksEnabled = true
    @AppStorage(VerityPetLifeModel.eerieIdlePreferenceKey) private var eerieIdleEnabled = true
    @AppStorage(VerityPrivacyPreferences.screenContextEnabledKey) private var screenContextEnabled = false
    @AppStorage(VerityPrivacyPreferences.excludedAppsKey) private var excludedAppsRaw = "Passwords, Keychain Access, 1Password, Bitwarden, LastPass"
    @AppStorage(VerityPrivacyPreferences.allowedAppsKey) private var allowedAppsRaw = ""
    @AppStorage(VerityPrivacyPreferences.blindModeEnabledKey) private var blindModeEnabled = false
    @AppStorage(VerityPrivacyPreferences.quietPresenceEnabledKey) private var quietPresenceEnabled = false
    @AppStorage(VerityUpdateChecker.automaticChecksKey) private var automaticUpdateChecks = true
    @AppStorage(VerityUpdateChecker.automaticInstallKey) private var automaticUpdateInstall = true
    @ObservedObject private var updateChecker = VerityUpdateChecker.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.9.0"
    }

    var body: some View {
        Form {
            Section("VERITY intelligence") {
                HStack(spacing: 9) {
                    Circle().fill(isConnected ? Color.green : Color.orange).frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(connectionStatus).font(.system(size: 13, weight: .semibold))
                        Text("Verity handles conversations, documents, and saved context.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(isChecking ? "Checking…" : "Test") { Task { await checkConnection() } }
                        .disabled(isChecking)
                }
                Text("Connection is handled securely by Verity.").font(.caption).foregroundStyle(.secondary)
            }

            Section("Desktop helper") {
                Toggle("Let Verity snack from Trash", isOn: $trashSnacksEnabled)
                Text("Verity stays docked in the lower-right corner, like a desktop helper. Click once to open the assistant; it does not wander or respond to dragging.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Quiet presence · shrink the desktop character", isOn: $quietPresenceEnabled)
                Text("Makes Verity smaller and visually quieter while you work. It does not start monitoring your activity.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Occasional unsettling idle stare", isOn: $eerieIdleEnabled)
                Text("At unpredictable intervals, while otherwise idle, Verity briefly holds a horror-style expression for about 2–4 seconds, then returns to his normal smile. He does not speak or move during it.")
                    .font(.caption).foregroundStyle(.secondary)
            }


            Section("Trust Center") {
                Toggle("Allow screen understanding", isOn: $screenContextEnabled)
                Toggle("Blind Mode · block all screen reading", isOn: $blindModeEnabled)
                Text("Blind Mode clears the current screen capture and prevents window listing, capture, and sending until you switch it off. Screen understanding otherwise remains manual: choose a window, capture once, review the text, then confirm before sending.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Allowed apps (optional, comma-separated)", text: $allowedAppsRaw)
                    .textFieldStyle(.roundedBorder)
                Text("When this list is not empty, only matching apps are shown. Leave it blank to allow all eligible apps.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Excluded apps (comma-separated)", text: $excludedAppsRaw)
                    .textFieldStyle(.roundedBorder)
                Text("Excluded apps always take priority. Password and keychain apps are blocked by default.")
                    .font(.caption).foregroundStyle(.secondary)
                Label("The screenshot stays on this Mac. Only the OCR text you review is sent after confirmation.", systemImage: "hand.raised.fill")
                    .font(.callout)
            }

            Section("Updates") {
                Toggle("Automatically check for updates", isOn: $automaticUpdateChecks)
                Toggle("Automatically download and install updates", isOn: $automaticUpdateInstall)
                Text("When enabled, VERITY downloads the latest stable release, checks its SHA-256 digest and app signature, replaces the installed app, and restarts. Auto-install requires VERITY.app to be directly inside a writable Applications folder.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: updateChecker.updateAvailable ? "arrow.down.circle.fill" : "arrow.clockwise.circle")
                        .foregroundStyle(updateChecker.updateAvailable ? .orange : .secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(updateChecker.status)
                            .font(.system(size: 13, weight: .semibold))
                        if let checked = updateChecker.lastCheckedAt {
                            Text("Last checked " + checked.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Checks GitHub Releases when VERITY launches and then periodically.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(updateChecker.isChecking ? "Checking…" : "Check now") {
                        Task { await updateChecker.checkNow() }
                    }
                    .disabled(updateChecker.isChecking)
                }
                if updateChecker.updateAvailable {
                    Button {
                        Task { await updateChecker.installAvailableUpdate() }
                    } label: {
                        Label(
                            updateChecker.isInstalling ? "Preparing update…" : "Install VERITY \(updateChecker.latestVersion) and restart",
                            systemImage: "arrow.down.to.line"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(updateChecker.isInstalling)
                    Button("Open manual installer") { updateChecker.openDownload() }
                        .disabled(updateChecker.isInstalling)
                }
                Text("VERITY checks every six hours. Automatic installation is enabled by default and can be switched off at any time.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Verity voice · ElevenLabs") {
                HStack(spacing: 9) {
                    Image(systemName: "waveform").font(.title2).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(VerityVoiceOption.all.first(where: { $0.id == selectedVoiceID })?.title ?? "Verity character voice").font(.system(size: 13, weight: .semibold))
                        Text("Warm, natural male voice with calmer conversational delivery").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: hasSavedElevenLabsKey ? "checkmark.circle.fill" : "key")
                        .foregroundStyle(hasSavedElevenLabsKey ? .green : .secondary)
                }
                Picker("Character voice", selection: $selectedVoiceID) {
                    ForEach(VerityVoiceOption.all) { voice in
                        Text(voice.title).tag(voice.id)
                    }
                }
                Text(VerityVoiceOption.all.first(where: { $0.id == selectedVoiceID })?.detail ?? "Original natural male character voice.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Speech engine: Eleven v4 · neutral delivery with phrase-by-phrase pre-generation.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Preview selected voice") {
                    Task { await previewSelectedVoice() }
                }
                .disabled(!hasSavedElevenLabsKey)

                SecureField("ElevenLabs API key", text: $elevenLabsKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save securely") { saveElevenLabsKey() }
                        .disabled(elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasSavedElevenLabsKey {
                        Button("Remove key", role: .destructive) { removeElevenLabsKey() }
                    }
                    Spacer()
                    Link("Get an API key", destination: URL(string: "https://elevenlabs.io/app/settings/api-keys")!)
                        .font(.caption)
                }
                Text(hasSavedElevenLabsKey
                    ? "Your key is stored in macOS Keychain, not in app preferences or source code."
                    : "Add an ElevenLabs API key to enable the expressive Verity voice. Without it, the app uses the best available male English voice on your Mac.")
                    .font(.caption).foregroundStyle(.secondary)
                if !voiceMessage.isEmpty {
                    Text(voiceMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }

            Section("Voice privacy") {
                Label("The microphone is used only while you activate the talk control. Speech recognition creates a transcript, which Verity uses to respond.", systemImage: "mic.badge.waveform")
                    .font(.callout)
                Text("Spoken replies are sent to ElevenLabs for voice synthesis when a key is configured. Document text is still extracted locally and requires its separate send confirmation.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Application", value: "VERITY")
                LabeledContent("Intelligence", value: "VERITY")
                LabeledContent("Voice", value: "ElevenLabs · Character voice")
                LabeledContent("Version", value: appVersion)
                Text("A docked desktop helper with a cheerful normal look and rare horror reactions.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 560, height: 690)
        .navigationTitle("Verity Settings")
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
                voiceMessage = "Add an ElevenLabs API key before previewing this voice."
                return
            }
            let sample = "Hello, I'm Verity. I'm here to help you work through things clearly and calmly. Show me what you're working on, and we'll take it one step at a time."
            let audio = try await VerityVoiceService.synthesize(sample, apiKey: apiKey)
            previewPlayer?.stop()
            let player = try AVAudioPlayer(data: audio)
            previewPlayer = player
            player.prepareToPlay()
            guard player.play() else { throw VerityVoiceError.invalidResponse }
            voiceMessage = "Playing the selected Verity character voice."
        } catch {
            voiceMessage = "Voice preview failed: \(error.localizedDescription)"
        }
    }

    private func saveElevenLabsKey() {
        do {
            try VerityKeychain.saveElevenLabsAPIKey(elevenLabsKey)
            elevenLabsKey = ""
            hasSavedElevenLabsKey = true
            voiceMessage = "ElevenLabs key saved in macOS Keychain."
        } catch {
            voiceMessage = "Couldn't save the key: \(error.localizedDescription)"
        }
    }

    private func removeElevenLabsKey() {
        do {
            try VerityKeychain.deleteElevenLabsAPIKey()
            elevenLabsKey = ""
            hasSavedElevenLabsKey = false
            voiceMessage = "ElevenLabs key removed. Verity will use the Mac voice."
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
            connectionStatus = "Connection unavailable · \(error.localizedDescription)"
        }
    }
}
