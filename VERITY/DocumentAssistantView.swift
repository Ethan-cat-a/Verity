import SwiftUI
import AppKit

struct VerityDocumentAssistantSheet: View {
    let file: VerityFile

    @StateObject private var assistant = VerityDocumentAssistantModel()
    @State private var question = ""
    @State private var pendingPrompt: String?
    @State private var isShowingUploadConfirmation = false
    @State private var selectedSource: VerityDocumentSource?
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

            Label("The file is read locally first. Extracted text is sent only after you confirm.", systemImage: "lock.shield")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 8) {
                Circle()
                    .fill(assistant.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(assistant.connectionStatus)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Check") {
                    Task { await assistant.checkConnection() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                quickAction("Summarize", prompt: "Summarize this document. Give me the purpose, main points, and conclusion. Keep it organized and easy to scan.")
                quickAction("Key points", prompt: "Extract the most important facts, claims, numbers, people, dates, and conclusions from this document. Group related points and reference page or section locations where possible.")
                quickAction("Explain simply", prompt: "Explain this document in plain language for someone new to the topic. Define important terms and use a simple example where helpful.")
            }
            .disabled(!assistant.isConnected || assistant.isWorking)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("VERITY'S ANSWER")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.1)
                    Spacer()
                    if assistant.isWorking {
                        ProgressView().controlSize(.small)
                        Text("Thinking…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if !assistant.sources.isEmpty {
                    Text("Tap a page or section citation to inspect its passage.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                ScrollView {
                    Text(linkedAnswer)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.vertical, 2)
                        .environment(\.openURL, OpenURLAction { url in
                            guard url.scheme == "verity-source",
                                  let id = url.pathComponents.last,
                                  let source = assistant.sources.first(where: { $0.id == id }) else {
                                return .discarded
                            }
                            selectedSource = source
                            return .handled
                        })
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
                    .disabled(!assistant.isConnected || assistant.isWorking)
                Button {
                    sendQuestion()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 25))
                }
                .buttonStyle(.plain)
                .disabled(!assistant.isConnected || assistant.isWorking || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Ask Verity")
            }
        }
        .padding(18)
        .frame(minWidth: 570, minHeight: 560)
        .task { await assistant.checkConnection() }
        .alert("Send extracted text to Verity?", isPresented: $isShowingUploadConfirmation) {
            Button("Cancel", role: .cancel) { pendingPrompt = nil }
            Button("Send reviewed text") {
                runPendingPrompt()
            }
        } message: {
            Text("Verity will extract text from “\(file.name)” on your Mac and send the extracted text with this question. The original file is not uploaded. You will be asked again before each new request. Continue?")
        }
        .sheet(item: $selectedSource) { source in
            VStack(alignment: .leading, spacing: 12) {
                Label(source.title, systemImage: "text.book.closed")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(file.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                ScrollView {
                    Text(source.excerpt)
                        .font(.system(size: 13, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                HStack {
                    Spacer()
                    Button("Done") { selectedSource = nil }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 440, minHeight: 300)
        }
    }

    private var linkedAnswer: AttributedString {
        let sourceByID = Dictionary(uniqueKeysWithValues: assistant.sources.map { ($0.id, $0) })
        let fullAnswer = assistant.answer as NSString
        guard let regex = try? NSRegularExpression(pattern: #"\[\[((?:P|S)\d+)\]\]"#) else {
            return AttributedString(assistant.answer)
        }

        var markdown = assistant.answer
        for match in regex.matches(in: assistant.answer, range: NSRange(location: 0, length: fullAnswer.length)).reversed() {
            let id = fullAnswer.substring(with: match.range(at: 1))
            guard let source = sourceByID[id] else { continue }
            let replacement = "[\(source.title)](verity-source://citation/\(source.id))"
            markdown = (markdown as NSString).replacingCharacters(in: match.range, with: replacement)
        }

        return (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(assistant.answer)
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
        guard assistant.isConnected else {
            Task { await assistant.checkConnection() }
            return
        }
        pendingPrompt = prompt
        isShowingUploadConfirmation = true
    }

    private func runPendingPrompt() {
        guard let prompt = pendingPrompt else { return }
        pendingPrompt = nil
        assistant.ask(fileURL: file.url, prompt: prompt)
    }
}
