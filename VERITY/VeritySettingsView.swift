import SwiftUI
import AVFoundation
import AppKit

/// The small set of controls that matter for the VERITY companion.
struct VeritySettingsView: View {
    @State private var connectionStatus = "Checking connection…"
    @State private var isConnected = false
    @State private var isChecking = false
    @State private var elevenLabsKey = ""
    @State private var fishAudioKey = ""
    @State private var hasSavedElevenLabsKey = false
    @State private var hasSavedFishAudioKey = false
    @State private var voiceMessage = ""
    @State private var previewPlayer: AVAudioPlayer?
    @AppStorage(VerityVoiceService.voicePreferenceKey) private var selectedVoiceID = VerityVoiceService.defaultVoiceID
    @AppStorage(VerityCharacterPreferences.eerieIdleEnabledKey) private var eerieIdleEnabled = true
    @AppStorage(VerityScreenWatcher.enabledKey) private var screenAwarenessEnabled = false
    @AppStorage(VerityScreenWatcher.closeExplicitTabsKey) private var closeExplicitTabs = true
    @AppStorage(VerityScreenWatcher.schoolHoursGamingGuardEnabledKey) private var schoolHoursGamingGuardEnabled = false
    @ObservedObject private var screenWatcher = VerityScreenWatcher.shared
    @AppStorage(VerityVoiceService.useElevenLabsPreferenceKey) private var useElevenLabsVoice = false
    @AppStorage(VerityVoiceService.useFishAudioPreferenceKey) private var useFishAudioVoice = false
    @AppStorage(VerityMemoryStore.enabledKey) private var memoryEnabled = true
    @State private var memoryMessage = ""
    @ObservedObject private var folderLibrary = VerityFolderLibrary.shared
    @State private var folderLibraryMessage = ""
    @AppStorage(VerityUpdateChecker.automaticChecksKey) private var automaticUpdateChecks = true
    @ObservedObject private var updateChecker = VerityUpdateChecker.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.0"
    }

    var body: some View {
        Form {
            Section("The character") {
                Toggle("Occasional unsettling stare", isOn: $eerieIdleEnabled)
                Text("Once in a while, Verity drops the smile and holds a strange stare for a few seconds. Screen awareness is a separate opt-in setting.")
                    .font(.caption).foregroundStyle(.secondary)
                Label("A bright yellow orb with a calm voice, a fixed smile, and an occasional unsettling stare.", systemImage: "face.smiling")
                    .font(.callout)
            }

            Section("Screen awareness") {
                Toggle("Let VERITY watch the active screen", isOn: $screenAwarenessEnabled)
                Toggle("Blur, then close obvious explicit browser tabs", isOn: $closeExplicitTabs)
                    .disabled(!screenAwarenessEnabled)
                Toggle("Scold me for gaming during school hours", isOn: $schoolHoursGamingGuardEnabled)
                    .disabled(!screenAwarenessEnabled)
                Text("School-hours guard runs Monday–Friday, 08:00–15:30 using this Mac's local time. It checks supported browser windows for CrazyGames, Poki and Roblox, and recognizes foreground Roblox, Steam and selected game apps. VERITY gives a special scolding, blurs the screen, then closes the matching browser tab or normally quits the game app. Save progress first: quitting a game may interrupt a session.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("When screen awareness is enabled, VERITY checks the frontmost window about every six seconds. Text recognition and keyword checks run locally; screenshots are not uploaded or saved. Obvious adult terms in visible browser text trigger a brief blur, then VERITY sends Command-W to close that tab. It can miss image-only content or misread context, and closing a tab may discard unsaved form contents.")
                    .font(.caption).foregroundStyle(.secondary)
                Label(screenWatcher.status, systemImage: screenWatcher.isWatching ? "eye" : "eye.slash")
                    .font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text(screenWatcher.lastScanSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    if let lastScanAt = screenWatcher.lastScanAt {
                        Text("Last checked " + lastScanAt.formatted(date: .omitted, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button("Check active window now") {
                        screenWatcher.runCheckNow()
                    }
                    .disabled(!screenAwarenessEnabled)
                }
            }

            Section("Voice") {
                Picker("Voice", selection: $selectedVoiceID) {
                    ForEach(VerityVoiceOption.all) { voice in
                        Text(voice.title).tag(voice.id)
                    }
                }
                .disabled(useFishAudioVoice)
                Toggle("Use Fish Audio · Verity community voice", isOn: Binding(
                    get: { useFishAudioVoice },
                    set: { enabled in
                        useFishAudioVoice = enabled
                        if enabled { useElevenLabsVoice = false }
                    }
                ))
                    .disabled(!hasSavedFishAudioKey)
                Toggle("Use ElevenLabs voice (adds synthesis time)", isOn: Binding(
                    get: { useElevenLabsVoice },
                    set: { enabled in
                        useElevenLabsVoice = enabled
                        if enabled { useFishAudioVoice = false }
                    }
                ))
                    .disabled(!hasSavedElevenLabsKey)
                HStack(spacing: 8) {
                    let activeProviderConfigured = (useFishAudioVoice && hasSavedFishAudioKey)
                        || (useElevenLabsVoice && hasSavedElevenLabsKey)
                    Image(systemName: activeProviderConfigured ? "checkmark.circle.fill" : "waveform")
                        .foregroundStyle(activeProviderConfigured ? .green : .secondary)
                    Text(useFishAudioVoice && hasSavedFishAudioKey
                         ? "Fish Audio Verity is enabled"
                         : (useElevenLabsVoice && hasSavedElevenLabsKey
                            ? "ElevenLabs character voice enabled"
                            : "Using the fast built-in Mac voice"))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Preview") { Task { await previewSelectedVoice() } }
                        .disabled(!activeProviderConfigured)
                }
                SecureField("Fish Audio API key", text: $fishAudioKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save Fish Audio key") { saveFishAudioKey() }
                        .disabled(fishAudioKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasSavedFishAudioKey {
                        Button("Remove", role: .destructive) { removeFishAudioKey() }
                    }
                    Spacer()
                    Link("Fish Audio API docs", destination: URL(string: "https://docs.fish.audio/api-reference/endpoint/openapi-v1/text-to-speech")!)
                        .font(.caption)
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
                Link("View the Fish Audio Verity community voice", destination: FishAudioVoiceService.voiceModelURL)
                    .font(.caption)
                Text("Fish Audio is an optional online voice: reply text is sent to Fish Audio for synthesis when enabled. The voice is a community-published model, not an official recording. API keys are stored in macOS Keychain. Without an enabled provider, Verity uses the built-in Mac voice.")
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

            Section("File awareness") {
                Toggle("Let VERITY search a folder I choose", isOn: Binding(
                    get: { folderLibrary.isEnabled },
                    set: { enabled in
                        if enabled {
                            requestFolderAccess()
                        } else {
                            folderLibrary.disable()
                            folderLibraryMessage = "Folder search is off. Its saved folder access and local index were removed."
                        }
                    }
                ))
                Text("Choose your home folder for broad coverage or a smaller folder. VERITY indexes supported PDFs, Word documents, text and code locally, skips hidden folders, Library and app packages, and keeps the text index in memory. The index is capped at 2,000 documents or 12 million characters. When you ask a question, up to 8,000 characters of relevant excerpts may be sent to NOVA; original files are not uploaded. Avoid folders with secrets. Turn this off any time to remove the saved folder access and index; earlier replies in an open chat remain.")
                    .font(.caption).foregroundStyle(.secondary)

                if folderLibrary.isEnabled {
                    Label(folderLibrary.folderName ?? "Selected folder", systemImage: "folder.fill")
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack {
                        Button("Choose another folder") { requestFolderAccess() }
                            .disabled(folderLibrary.isIndexing)
                        Button(folderLibrary.isIndexing ? "Indexing…" : "Refresh index") {
                            Task { await folderLibrary.refreshIndex() }
                        }
                        .disabled(folderLibrary.isIndexing)
                    }
                    Text(folderLibrary.status)
                        .font(.caption).foregroundStyle(.secondary)
                    if let error = folderLibrary.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                    }
                }
                if !folderLibraryMessage.isEmpty {
                    Text(folderLibraryMessage).font(.caption).foregroundStyle(.secondary)
                }
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
                Text("Checks GitHub when due at launch and every six hours. VERITY asks before downloading and installing an update, then verifies it and restarts. Installation needs VERITY.app in a writable Applications folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .frame(width: 500, height: 700)
        .navigationTitle("VERITY")
        .task {
            VerityVoiceService.migrateLegacyVoicePreferenceIfNeeded()
            selectedVoiceID = UserDefaults.standard.string(forKey: VerityVoiceService.voicePreferenceKey)
                ?? VerityVoiceService.defaultVoiceID
            UserDefaults.standard.register(defaults: [VerityUpdateChecker.automaticChecksKey: true])
            refreshVoiceKeyStatus()
            await checkConnection()
            if automaticUpdateChecks { updateChecker.startAutomaticChecks() }
            screenWatcher.startIfEnabled()
        }
        .onDisappear { previewPlayer?.stop() }
        .onChange(of: screenAwarenessEnabled) { enabled in
            screenWatcher.setEnabled(enabled)
        }
        .onChange(of: closeExplicitTabs) { enabled in
            screenWatcher.setCloseEnabled(enabled)
        }
        .onChange(of: schoolHoursGamingGuardEnabled) { enabled in
            screenWatcher.setSchoolHoursGamingGuardEnabled(enabled)
        }
        .onChange(of: automaticUpdateChecks) { enabled in
            if enabled { updateChecker.startAutomaticChecks() }
            else { updateChecker.stopAutomaticChecks() }
        }
    }

    private func refreshVoiceKeyStatus() {
        do {
            hasSavedElevenLabsKey = try VerityKeychain.readElevenLabsAPIKey()?.isEmpty == false
            hasSavedFishAudioKey = try VerityKeychain.readFishAudioAPIKey()?.isEmpty == false
        } catch {
            hasSavedElevenLabsKey = false
            hasSavedFishAudioKey = false
            voiceMessage = error.localizedDescription
        }
    }

    @MainActor
    private func requestFolderAccess() {
        if !folderLibrary.isEnabled {
            let explanation = NSAlert()
            explanation.messageText = "Let VERITY search a folder?"
            explanation.informativeText = "VERITY will scan supported PDFs, Word documents, text and code inside the folder you choose, on this Mac. It does not upload whole files. For each question, up to 8,000 characters of locally matched excerpts may be sent to NOVA. Hidden folders, Library and app/package contents are skipped. The local index is capped at 2,000 documents or 12 million characters. Choose a smaller folder if your home folder contains secrets. Turning this off removes VERITY's saved folder access and local index; earlier replies in an open chat remain."
            explanation.addButton(withTitle: "Choose Folder")
            explanation.addButton(withTitle: "Cancel")
            guard explanation.runModal() == .alertFirstButtonReturn else { return }
        }

        let panel = NSOpenPanel()
        panel.title = "Choose a folder for VERITY"
        panel.message = "Choose your home folder for broad coverage, or select a narrower folder."
        panel.prompt = "Allow Folder Search"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let folderURL = panel.url else { return }

        do {
            try folderLibrary.enable(folderURL: folderURL)
            folderLibraryMessage = ""
            Task { await folderLibrary.refreshIndex() }
        } catch {
            folderLibraryMessage = "Couldn't enable folder search: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func previewSelectedVoice() async {
        do {
            let sample = "I'm Verity. The smartest ball on your desktop. Ask me anything; I already know."
            let audio: Data
            if useFishAudioVoice {
                guard let apiKey = try VerityKeychain.readFishAudioAPIKey(), !apiKey.isEmpty else {
                    voiceMessage = "Add a Fish Audio API key before previewing."
                    return
                }
                audio = try await FishAudioVoiceService.synthesize(sample, apiKey: apiKey)
            } else {
                guard let apiKey = try VerityKeychain.readElevenLabsAPIKey(), !apiKey.isEmpty else {
                    voiceMessage = "Add an ElevenLabs API key before previewing."
                    return
                }
                audio = try await VerityVoiceService.synthesize(sample, apiKey: apiKey)
            }
            previewPlayer?.stop()
            let player = try AVAudioPlayer(data: audio)
            previewPlayer = player
            player.prepareToPlay()
            guard player.play() else { throw VerityVoiceError.invalidResponse }
            voiceMessage = useFishAudioVoice ? "Playing Fish Audio's community Verity voice." : "Playing Verity."
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

    private func saveFishAudioKey() {
        do {
            try VerityKeychain.saveFishAudioAPIKey(fishAudioKey)
            fishAudioKey = ""
            hasSavedFishAudioKey = true
            useFishAudioVoice = true
            useElevenLabsVoice = false
            voiceMessage = "Fish Audio key saved securely. Fish Audio Verity is enabled."
        } catch {
            voiceMessage = "Couldn't save the key: \(error.localizedDescription)"
        }
    }

    private func removeFishAudioKey() {
        do {
            try VerityKeychain.deleteFishAudioAPIKey()
            fishAudioKey = ""
            hasSavedFishAudioKey = false
            useFishAudioVoice = false
            voiceMessage = "Fish Audio key removed. Verity will use the Mac voice or your selected ElevenLabs voice."
        } catch {
            voiceMessage = "Couldn't remove the key: \(error.localizedDescription)"
        }
    }

    private var activeProviderConfigured: Bool {
        (useFishAudioVoice && hasSavedFishAudioKey)
            || (useElevenLabsVoice && hasSavedElevenLabsKey)
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
