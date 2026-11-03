import SwiftUI

struct VeritySettingsView: View {
    @AppStorage("verity.model") private var modelID = "gpt-6-luna"
    @State private var apiKeyDraft = ""
    @State private var hasSavedKey = false
    @State private var feedback = ""
    @State private var isError = false

    var body: some View {
        Form {
            Section("AI brain") {
                Picker("OpenAI model", selection: $modelID) {
                    Text("GPT-6 Luna — efficient").tag("gpt-6-luna")
                    Text("GPT-6.1 Terra — balanced").tag("gpt-6.1-terra")
                    Text("GPT-6.1 Sol — advanced").tag("gpt-6.1-sol")
                    Text("GPT-6 Astra — flagship").tag("gpt-6-astra")
                }
                .pickerStyle(.menu)

                SecureField("OpenAI API key", text: $apiKeyDraft)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save API key") { saveKey() }
                        .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasSavedKey {
                        Button("Remove saved key", role: .destructive) { removeKey() }
                    }
                    Spacer()
                    Text(hasSavedKey ? "Key stored in Keychain" : "No API key saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Link("Get an OpenAI API key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.caption)

                Text("API usage is billed separately by OpenAI. Verity stores the key in macOS Keychain, not in its project files or preferences.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Document privacy") {
                Label("A document is only sent to OpenAI after you choose an analysis action and confirm.", systemImage: "lock.shield")
                    .font(.callout)
                Text("Verity sends the selected document to the OpenAI Responses API for analysis. It does not upload documents automatically when you drop them onto the character.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !feedback.isEmpty {
                Section {
                    Text(feedback)
                        .foregroundStyle(isError ? .red : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 520, height: 410)
        .navigationTitle("Verity Settings")
        .onAppear(perform: refreshKeyStatus)
    }

    private func refreshKeyStatus() {
        do {
            hasSavedKey = try VerityKeychain.readAPIKey() != nil
        } catch {
            hasSavedKey = false
            feedback = error.localizedDescription
            isError = true
        }
    }

    private func saveKey() {
        do {
            try VerityKeychain.saveAPIKey(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines))
            apiKeyDraft = ""
            hasSavedKey = true
            feedback = "Saved securely. Verity is ready to read documents."
            isError = false
        } catch {
            feedback = error.localizedDescription
            isError = true
        }
    }

    private func removeKey() {
        do {
            try VerityKeychain.deleteAPIKey()
            hasSavedKey = false
            apiKeyDraft = ""
            feedback = "The saved API key was removed."
            isError = false
        } catch {
            feedback = error.localizedDescription
            isError = true
        }
    }
}
