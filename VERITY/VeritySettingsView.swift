
import SwiftUI

struct VeritySettingsView: View {
    @State private var connectionStatus = "Checking connection…"
    @State private var isConnected = false
    @State private var isChecking = false
    @State private var elevenLabsKey = ""
    @State private var hasSavedElevenLabsKey = false
    @State private var voiceMessage = ""
    @AppStorage(VerityVoiceService.voicePreferenceKey) private var selectedVoiceID = VerityVoiceService.defaultVoiceID
    @AppStorage(VerityVoiceService.speedPreferenceKey) private var voiceSpeed = 1.08
    @AppStorage(VerityPetLifeModel.trashSnacksPreferenceKey) private var trashSnacksEnabled = true
    @AppStorage(VerityPrivacyPreferences.screenContextEnabledKey) private var screenContextEnabled = false
    @AppStorage(VerityPrivacyPreferences.excludedAppsKey) private var excludedAppsRaw = "Passwords, Keychain Access, 1Password, Bitwarden, LastPass"
    @AppStorage(VerityUpdateChecker.automaticChecksKey) private var automaticUpdateChecks = true
    @ObservedObject private var updateChecker = VerityUpdateChecker.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.6.0"
    }

    var body: some View {
        Form {
            Section("VERITY intelligence") {
                HStack(spacing: 9) {
                    Circle().fill(isConnected ? Color.green : Color.orange).frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(connectionStatus).font(.system(size: 13, weight: .semibold))
                        Text("NOVA V8 powers Verity's conversations and document understanding.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(isChecking ? "Checking…" : "Test") { Task { await checkConnection() } }
                        .disabled(isChecking)
                }
                Text("Connection is handled securely by Verity.").font(.caption).foregroundStyle(.secondary)
            }

            Section("Verity's chaotic pet life") {
                Toggle("Let Verity snack from Trash", isOn: $trashSnacksEnabled)
                Text("When hungry, Verity occasionally picks a random item name from your user Trash and performs a chomping animation. It only reads the filename. It never opens, deletes, moves, renames, or restores the item. Turn this off any time.")
                    .font(.caption).foregroundStyle(.secondary)
                Label("Verity wanders around your desktop while idle. Drag its face to move it; it complains when you let go.", systemImage: "move.3d")
                    .font(.callout)
            }


            Section("Trust Center") {
                Toggle("Allow screen understanding", isOn: $screenContextEnabled)
                Text("Off by default. When enabled, Verity can capture one window only after you choose it and press Capture. Text is read locally, shown for review, and sent only after you confirm. No background screen recording.")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Excluded apps (comma-separated)", text: $excludedAppsRaw)
                    .textFieldStyle(.roundedBorder)
                Text("Password and keychain apps are excluded by default. Add any other app names you never want to appear in the capture list.")
                    .font(.caption).foregroundStyle(.secondary)
                Label("The screenshot stays on this Mac. Only the OCR text you review is sent after confirmation.", systemImage: "hand.raised.fill")
                    .font(.callout)
            }

            Section("Updates") {
                Toggle("Automatically check for updates", isOn: $automaticUpdateChecks)
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
                        updateChecker.openDownload()
                    } label: {
                        Label("Download VERITY \(updateChecker.latestVersion)", systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Text("VERITY checks automatically and offers the official installer. Installing is always your choice; it never silently replaces the running app.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Verity voice · ElevenLabs") {
                HStack(spacing: 9) {
                    Image(systemName: "waveform").font(.title2).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(VerityVoiceOption.all.first(where: { $0.id == selectedVoiceID })?.title ?? "Bright cartoon").font(.system(size: 13, weight: .semibold))
                        Text("Expressive, low-latency character speech").font(.caption).foregroundStyle(.secondary)
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
                Text(VerityVoiceOption.all.first(where: { $0.id == selectedVoiceID })?.detail ?? "Expressive cartoon-character voice.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text("Speaking pace")
                    Slider(value: $voiceSpeed, in: 0.90...1.20, step: 0.02)
                    Text(String(format: "%.2fx", voiceSpeed))
                        .font(.caption.monospacedDigit())
                        .frame(width: 44, alignment: .trailing)
                }
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
                    : "Add an ElevenLabs API key to enable Verity's selected voice. Until then, conversation uses the Mac's built-in voice.")
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
                Text("A small, expressive desktop companion for conversations and files.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 560, height: 690)
        .navigationTitle("Verity Settings")
        .task {
            UserDefaults.standard.register(defaults: [VerityUpdateChecker.automaticChecksKey: true])
            refreshVoiceKeyStatus()
            await checkConnection()
            if automaticUpdateChecks { updateChecker.startAutomaticChecks() }
        }
        .onChange(of: automaticUpdateChecks) { enabled in
            if enabled { updateChecker.startAutomaticChecks() }
            else { updateChecker.stopAutomaticChecks() }
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
