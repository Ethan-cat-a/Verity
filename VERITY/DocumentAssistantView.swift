import SwiftUI
import AppKit

struct VerityDocumentAssistantSheet: View {
    let file: VerityFile

    @StateObject private var assistant = VerityDocumentAssistantModel()
    @State private var question = ""
    @State private var pendingPrompt: String?
    @State private var hasConfirmedUpload = false
    @State private var isShowingUploadConfirmation = false
    @State private var hasAPIKey = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                VerityFace(size: 48, mood: .happy)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Verity read this")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(file.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Label("Your document is only sent after you choose an action and confirm.", systemImage: "lock.shield")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

            if !hasAPIKey {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect Verity's brain first")
                        .font(.headline)
                    Text("Add an OpenAI API key in Settings. Verity keeps it in macOS Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button {
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        } label: {
                            Label("Open VERITY Settings", systemImage: "gearshape")
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Refresh") { checkKey() }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 8) {
                quickAction("Summarize", prompt: "Summarize this document. Give me the purpose, main points, and conclusion. Keep it organized and easy to scan.")
                quickAction("Key points", prompt: "Extract the most important facts, claims, numbers, people, dates, and conclusions from this document. Group related points and reference page or section locations where possible.")
                quickAction("Explain simply", prompt: "Explain this document in plain language for someone new to the topic. Define important terms and use a simple example where helpful.")
            }
            .disabled(!hasAPIKey || assistant.isWorking)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("VERITY'S ANSWER")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.1)
                    Spacer()
                    if assistant.isWorking {
                        ProgressView().controlSize(.small)
                        Text("Reading...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                ScrollView {
                    Text(assistant.answer)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.vertical, 2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 190, maxHeight: .infinity)
                .background(.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            }

            if let error = assistant.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack(spacing: 8) {
                TextField("Ask Verity something about this file...", text: $question, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .onSubmit { sendQuestion() }
                    .disabled(!hasAPIKey || assistant.isWorking)
                Button {
                    sendQuestion()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 25))
                }
                .buttonStyle(.plain)
                .disabled(!hasAPIKey || assistant.isWorking || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Ask Verity")
            }
        }
        .padding(18)
        .frame(minWidth: 570, minHeight: 560)
        .onAppear(perform: checkKey)
        .alert("Send this document to OpenAI?", isPresented: $isShowingUploadConfirmation) {
            Button("Cancel", role: .cancel) { pendingPrompt = nil }
            Button("Send to OpenAI") {
                hasConfirmedUpload = true
                runPendingPrompt()
            }
        } message: {
            Text("Verity will send “\(file.name)” to the OpenAI Responses API for analysis. The file is not sent until you confirm. Continue?")
        }
    }

    private func quickAction(_ title: String, prompt: String) -> some View {
        Button(title) { submit(prompt) }
            .buttonStyle(.bordered)
            .controlSize(.regular)
    }

    private func sendQuestion() {
        let prompt = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        question = ""
        submit(prompt)
    }

    private func submit(_ prompt: String) {
        guard hasAPIKey else { return }
        pendingPrompt = prompt
        if hasConfirmedUpload {
            runPendingPrompt()
        } else {
            isShowingUploadConfirmation = true
        }
    }

    private func runPendingPrompt() {
        guard let prompt = pendingPrompt else { return }
        pendingPrompt = nil
        assistant.ask(fileURL: file.url, prompt: prompt)
    }

    private func checkKey() {
        hasAPIKey = (try? VerityKeychain.readAPIKey()) != nil
    }
}
