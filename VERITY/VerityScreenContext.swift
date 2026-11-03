import SwiftUI
import AppKit
import ScreenCaptureKit
import Vision
import Combine

enum VerityPrivacyPreferences {
    static let screenContextEnabledKey = "verity.privacy.screenContextEnabled"
    static let excludedAppsKey = "verity.privacy.excludedApps"
    static let allowedAppsKey = "verity.privacy.allowedApps"
    static let blindModeEnabledKey = "verity.privacy.blindModeEnabled"
    static let quietPresenceEnabledKey = "verity.presence.quietMode"
}

struct VerityScreenWindow: Identifiable {
    let window: SCWindow
    let applicationName: String
    let title: String

    var id: UInt32 { window.windowID }
    var displayTitle: String { "\(applicationName) — \(title)" }
}

private struct VerityScreenCaptureResult {
    let image: NSImage
    let text: String
}

private enum VerityScreenCaptureService {
    static let defaultExcludedNames: Set<String> = [
        "passwords", "keychain access", "1password", "bitwarden", "lastpass", "dashlane", "keeper"
    ]

    static func availableWindows(
        excludingAppNames: Set<String>,
        allowedAppNames: Set<String>
    ) async throws -> [VerityScreenWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let excluded = defaultExcludedNames.union(excludingAppNames.map { $0.lowercased() })
        let allowed = Set(allowedAppNames.map { $0.lowercased() }.filter { !$0.isEmpty })
        return content.windows.compactMap { window in
            guard window.isOnScreen,
                  window.owningApplication?.processID != ProcessInfo.processInfo.processIdentifier,
                  window.frame.width >= 120,
                  window.frame.height >= 80 else { return nil }

            let appName = window.owningApplication?.applicationName ?? "Unknown app"
            let title = (window.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let bundleID = window.owningApplication?.bundleIdentifier.lowercased() ?? ""
            let searchableName = (appName + " " + bundleID).lowercased()
            guard !excluded.contains(where: { !$0.isEmpty && searchableName.contains($0) }) else { return nil }
            guard allowed.isEmpty || allowed.contains(where: { searchableName.contains($0) }) else { return nil }
            return VerityScreenWindow(window: window, applicationName: appName, title: title)
        }
        .sorted {
            if $0.applicationName.localizedCaseInsensitiveCompare($1.applicationName) == .orderedSame {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.applicationName.localizedCaseInsensitiveCompare($1.applicationName) == .orderedAscending
        }
    }

    @available(macOS 14.0, *)
    static func capture(window: SCWindow) async throws -> VerityScreenCaptureResult {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = max(320, min(Int(window.frame.width * 2), 2400))
        configuration.height = max(240, min(Int(window.frame.height * 2), 2400))
        configuration.capturesAudio = false
        configuration.showsCursor = false

        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.006
        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

        let observations = (request.results ?? []).sorted {
            if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.015 {
                return $0.boundingBox.midY > $1.boundingBox.midY
            }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }
        let recognized = observations.compactMap { $0.topCandidates(1).first?.string }
        let text = recognized.joined(separator: "\n")
        return VerityScreenCaptureResult(
            image: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)),
            text: text
        )
    }
}

@MainActor
final class VerityScreenContextModel: ObservableObject {
    @Published var windows: [VerityScreenWindow] = []
    @Published var selectedWindowID: UInt32?
    @Published var previewImage: NSImage?
    @Published var extractedText = ""
    @Published var capturedWindowTitle = ""
    @Published var answer = ""
    @Published var status = "Choose a window to understand."
    @Published var errorMessage: String?
    @Published var isLoadingWindows = false
    @Published var isCapturing = false
    @Published var isAsking = false

    func refreshWindows(excludingAppNames: Set<String>, allowedAppNames: Set<String> = []) async {
        guard !UserDefaults.standard.bool(forKey: VerityPrivacyPreferences.blindModeEnabledKey) else {
            clearLocalScreenData()
            status = "Blind Mode is on. Screen reading is paused."
            return
        }
        guard !isLoadingWindows else { return }
        isLoadingWindows = true
        errorMessage = nil
        status = "Finding visible windows…"
        defer { isLoadingWindows = false }
        do {
            windows = try await VerityScreenCaptureService.availableWindows(
                excludingAppNames: excludingAppNames,
                allowedAppNames: allowedAppNames
            )
            if let selectedWindowID, !windows.contains(where: { $0.id == selectedWindowID }) {
                self.selectedWindowID = nil
            }
            if selectedWindowID == nil { selectedWindowID = windows.first?.id }
            status = windows.isEmpty
                ? "No eligible windows found. Open a window and refresh."
                : "\(windows.count) eligible window(s) found."
        } catch {
            status = "Screen access needs permission."
            errorMessage = "\(error.localizedDescription)\nOpen System Settings → Privacy & Security → Screen Recording, allow VERITY, then quit and reopen it."
        }
    }

    func clearLocalScreenData() {
        previewImage = nil
        extractedText = ""
        capturedWindowTitle = ""
        answer = ""
        windows = []
        selectedWindowID = nil
        errorMessage = nil
    }

    func captureSelected() async {
        guard !UserDefaults.standard.bool(forKey: VerityPrivacyPreferences.blindModeEnabledKey) else {
            clearLocalScreenData()
            status = "Blind Mode is on. No screen content was captured."
            return
        }
        guard !isCapturing,
              let selectedWindowID,
              let entry = windows.first(where: { $0.id == selectedWindowID }) else { return }
        guard #available(macOS 14.0, *) else {
            errorMessage = "Window capture requires macOS 14 or later."
            return
        }

        isCapturing = true
        errorMessage = nil
        previewImage = nil
        extractedText = ""
        capturedWindowTitle = entry.displayTitle
        status = "Capturing the selected window once…"
        defer { isCapturing = false }
        do {
            let result = try await VerityScreenCaptureService.capture(window: entry.window)
            previewImage = result.image
            extractedText = result.text
            status = result.text.isEmpty
                ? "Captured locally, but no readable text was found."
                : "Captured locally · review or redact the recognized text below."
        } catch {
            errorMessage = "\(error.localizedDescription)\nCheck VERITY's Screen Recording permission in System Settings, then restart VERITY."
            status = "Capture failed."
        }
    }

    func ask(question: String) {
        let prompt = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !UserDefaults.standard.bool(forKey: VerityPrivacyPreferences.blindModeEnabledKey),
              !isAsking, !prompt.isEmpty, !context.isEmpty else { return }

        isAsking = true
        errorMessage = nil
        answer = "Verity is thinking…"
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isAsking = false }
            do {
                answer = try await VerityNovaClient().analyzeScreenContext(
                    windowTitle: capturedWindowTitle,
                    recognizedText: context,
                    prompt: prompt
                )
            } catch {
                errorMessage = error.localizedDescription
                answer = "I couldn't finish understanding that window."
            }
        }
    }
}

struct VerityScreenContextSheet: View {
    @AppStorage(VerityPrivacyPreferences.screenContextEnabledKey) private var screenContextEnabled = false
    @AppStorage(VerityPrivacyPreferences.excludedAppsKey) private var excludedAppsRaw = "Passwords, Keychain Access, 1Password, Bitwarden, LastPass"
    @AppStorage(VerityPrivacyPreferences.allowedAppsKey) private var allowedAppsRaw = ""
    @AppStorage(VerityPrivacyPreferences.blindModeEnabledKey) private var blindModeEnabled = false
    @StateObject private var model = VerityScreenContextModel()
    @State private var question = "Explain what I'm looking at and what I should do next."
    @State private var focusedSelection = ""
    @State private var isConfirmingSend = false
    @Environment(\.dismiss) private var dismiss

    private var excludedAppNames: Set<String> {
        Set(excludedAppsRaw.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
    }

    private var allowedAppNames: Set<String> {
        Set(allowedAppsRaw.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty })
    }

    private func prepareStudyAction(_ prompt: String) {
        var prepared = prompt
        let focus = focusedSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        if !focus.isEmpty {
            prepared += "\n\nUSER-SELECTED FOCUS (prioritize this text):\n\(focus)"
        }
        question = prepared
        isConfirmingSend = true
    }

    private func copyAnswer() {
        guard !model.answer.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.answer, forType: .string)
        model.status = "Answer copied."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VerityFace(size: 46, mood: .happy)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Understand a window")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("One capture · local reading · your approval")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Label("VERITY does not watch your desktop continuously. It captures only the window you select, when you press Capture.", systemImage: "hand.raised.fill")
                .font(.callout)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))

            Toggle("Blind Mode · pause all screen reading", isOn: $blindModeEnabled)
            Text("When enabled, Verity clears the current capture and will not list, capture, or send screen content.")
                .font(.caption).foregroundStyle(.secondary)

            Toggle("Allow screen understanding", isOn: $screenContextEnabled)

            if blindModeEnabled {
                Label("Blind Mode is active. Screen access is paused.", systemImage: "eye.slash.fill")
                    .font(.callout)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            } else if screenContextEnabled {
                TextField("Allowed apps (optional; leave blank for all eligible apps)", text: $allowedAppsRaw)
                    .textFieldStyle(.roundedBorder)
                Text("Only windows from these apps will be listed. Your excluded-app list always takes priority.")
                    .font(.caption).foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Picker("Window", selection: $model.selectedWindowID) {
                        ForEach(model.windows) { window in
                            Text(window.displayTitle).tag(Optional(window.id))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Button(model.isLoadingWindows ? "Loading…" : "Refresh") {
                        Task {
                            await model.refreshWindows(
                                excludingAppNames: excludedAppNames,
                                allowedAppNames: allowedAppNames
                            )
                        }
                    }
                    .disabled(model.isLoadingWindows)
                    Button(model.isCapturing ? "Capturing…" : "Capture") {
                        Task { await model.captureSelected() }
                    }
                    .disabled(model.isCapturing || model.selectedWindowID == nil)
                    .buttonStyle(.borderedProminent)
                }

                if let image = model.previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 210)
                        .background(.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("LOCAL OCR TEXT · EDIT OR REDACT BEFORE SENDING")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.5)
                        Spacer()
                        Text("\(model.extractedText.count) chars").font(.caption2).foregroundStyle(.secondary)
                    }
                    TextEditor(text: $model.extractedText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 105, maxHeight: 155)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.10), lineWidth: 1))
                }

                TextField("Optional focus: paste a selected sentence, equation, or paragraph", text: $focusedSelection, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    Button("Screen → quiz") {
                        prepareStudyAction("""
                        Create a 6-question practice quiz using only the reviewed screen content. Start with core understanding, then increase difficulty. Use clear questions and plausible answer choices. Do not reveal the answers yet. After I respond, mark my answers and explain any misconceptions.
                        """)
                    }
                    Button("Make a study set") {
                        prepareStudyAction("""
                        Turn the reviewed content into a compact study set: a clear summary, 8 concise front/back flashcards, and 5 retrieval-practice questions. Preserve important definitions, formulas, examples, and qualifications. Do not invent missing information.
                        """)
                    }
                    Button("Socratic guidance") {
                        prepareStudyAction("""
                        Tutor me Socratically using only the reviewed content. Do not give the final answer or complete the work for me. Ask one focused guiding question at a time, give a small hint only when needed, and adapt to my response.
                        """)
                    }
                    Button("Practice test") {
                        prepareStudyAction("""
                        Create an 8-question practice test from the reviewed content, suitable for a 15-minute attempt. Mix question types where appropriate, keep the answer key hidden, and do not reveal solutions until I submit my answers. When I submit them, score each concept and explain mistakes.
                        """)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                TextField("Ask Verity about this window…", text: $question, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)

                HStack {
                    Text(model.status).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Send reviewed text") { isConfirmingSend = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isAsking || model.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if model.isAsking {
                    ProgressView("Thinking…").controlSize(.small)
                }
                if !model.answer.isEmpty {
                    HStack {
                        Text("VERITY'S RESPONSE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Copy") { copyAnswer() }
                            .buttonStyle(.borderless)
                    }
                    ScrollView {
                        Text(model.answer)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 70, maxHeight: 160)
                    .padding(10)
                    .background(.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                }
            } else {
                Text("Screen understanding is off. Turn it on here or in Settings → Trust Center. VERITY still won't capture anything until you choose a window and press Capture.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
        }
        .padding(18)
        .frame(minWidth: 680, minHeight: 690)
        .task {
            if screenContextEnabled && !blindModeEnabled {
                await model.refreshWindows(
                    excludingAppNames: excludedAppNames,
                    allowedAppNames: allowedAppNames
                )
            }
        }
        .onChange(of: blindModeEnabled) { enabled in
            if enabled {
                model.clearLocalScreenData()
                model.status = "Blind Mode is on. Screen reading is paused."
            } else if screenContextEnabled {
                Task {
                    await model.refreshWindows(
                        excludingAppNames: excludedAppNames,
                        allowedAppNames: allowedAppNames
                    )
                }
            }
        }
        .onChange(of: screenContextEnabled) { enabled in
            if !enabled {
                model.clearLocalScreenData()
                model.status = "Screen understanding is off."
            } else if !blindModeEnabled {
                Task {
                    await model.refreshWindows(
                        excludingAppNames: excludedAppNames,
                        allowedAppNames: allowedAppNames
                    )
                }
            }
        }
        .alert("Send selected screen text to Verity?", isPresented: $isConfirmingSend) {
            Button("Cancel", role: .cancel) {}
            Button("Send reviewed text") {
                model.ask(question: question)
            }
        } message: {
            Text("Only the OCR text shown above and your question are sent to your assistant service. The screenshot itself stays on this Mac. Continue?")
        }
    }
}
