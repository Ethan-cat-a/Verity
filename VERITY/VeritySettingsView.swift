
import SwiftUI

struct VeritySettingsView: View {
    @State private var connectionStatus = "Checking NOVA V8…"
    @State private var isConnected = false
    @State private var isChecking = false
    @State private var elevenLabsKey = ""
    @State private var hasSavedElevenLabsKey = false
    @State private var voiceMessage = ""
    @AppStorage(VerityPetLifeModel.trashSnacksPreferenceKey) private var trashSnacksEnabled = true

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.4.4"
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
                Link("Open NOVA V8", destination: URL(string: "https://nova-v8.vercel.app")!)
                    .font(.caption)
            }

            Section("Verity's chaotic pet life") {
                Toggle("Let Verity snack from Trash", isOn: $trashSnacksEnabled)
                Text("When hungry, Verity occasionally picks a random item name from your user Trash and performs a chomping animation. It only reads the filename. It never opens, deletes, moves, renames, or restores the item. Turn this off any time.")
                    .font(.caption).foregroundStyle(.secondary)
                Label("Verity wanders around your desktop while idle. Drag its face to move it; it complains when you let go.", systemImage: "move.3d")
                    .font(.callout)
            }

            Section("Verity voice · ElevenLabs") {
                HStack(spacing: 9) {
                    Image(systemName: "waveform").font(.title2).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Callie · Friendly and sweet").font(.system(size: 13, weight: .semibold))
                        Text("Eleven Flash · expressive, low-latency speech").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: hasSavedElevenLabsKey ? "checkmark.circle.fill" : "key")
                        .foregroundStyle(hasSavedElevenLabsKey ? .green : .secondary)
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
                Label("The microphone is used only while you activate the talk control. Speech recognition creates a transcript, which is sent to NOVA V8 for a reply.", systemImage: "mic.badge.waveform")
                    .font(.callout)
                Text("Spoken replies are sent to ElevenLabs for voice synthesis when a key is configured. Document text is still extracted locally and requires its separate send confirmation.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Application", value: "VERITY")
                LabeledContent("Intelligence", value: "NOVA V8")
                LabeledContent("Voice", value: "ElevenLabs · Callie")
                LabeledContent("Version", value: appVersion)
                Text("A small, expressive desktop companion for conversations and files.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 560, height: 690)
        .navigationTitle("Verity Settings")
        .task { refreshVoiceKeyStatus(); await checkConnection() }
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
                connectionStatus = "NOVA V8 connected"
            } else if health.ok == true {
                isConnected = false
                connectionStatus = "NOVA V8 online · server key needs attention"
            } else {
                isConnected = false
                connectionStatus = "NOVA V8 needs attention"
            }
        } catch {
            isConnected = false
            connectionStatus = "Connection unavailable · \(error.localizedDescription)"
        }
    }
}
