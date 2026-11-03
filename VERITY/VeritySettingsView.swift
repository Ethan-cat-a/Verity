import SwiftUI

struct VeritySettingsView: View {
    @State private var connectionStatus = "Checking NOVA V8…"
    @State private var isConnected = false
    @State private var isChecking = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.1"
    }

    var body: some View {
        Form {
            Section("VERITY intelligence") {
                HStack(spacing: 9) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(connectionStatus)
                            .font(.system(size: 13, weight: .semibold))
                        Text("VERITY uses NOVA V8 as its AI brain.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(isChecking ? "Checking…" : "Test connection") {
                        Task { await checkConnection() }
                    }
                    .disabled(isChecking)
                }

                Link("NOVA V8 service", destination: URL(string: "https://nova-v8.vercel.app")!)
                    .font(.caption)
                Text("No separate AI API key is needed in VERITY. Requests use the existing NOVA V8 server, which keeps its provider credentials on the server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Document privacy") {
                Label("Files are read locally first. Extracted text is sent to NOVA V8 only after you choose an analysis action and confirm.", systemImage: "lock.shield")
                    .font(.callout)
                Text("VERITY does not upload the original file as an attachment. Text extraction is performed on your Mac. Scanned PDF OCR and spreadsheet extraction are not included in this early build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Application", value: "VERITY")
                LabeledContent("AI engine", value: "NOVA V8")
                LabeledContent("Version", value: appVersion)
                Text("VERITY is a native macOS desktop companion. More desktop skills and voice features will be added in later releases.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .frame(width: 520, height: 390)
        .navigationTitle("Verity Settings")
        .task { await checkConnection() }
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
