import SwiftUI
import AppKit
import ScreenCaptureKit
import Vision
import Combine

enum VerityPrivacyPreferences {
    static let screenContextEnabledKey = "verity.privacy.screenContextEnabled"
    static let excludedAppsKey = "verity.privacy.excludedApps"
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

    static func availableWindows(excludingAppNames: Set<String>) async throws -> [VerityScreenWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let excluded = defaultExcludedNames.union(excludingAppNames.map { $0.lowercased() })
        return content.windows.compactMap { window in
            guard window.isOnScreen,
                  window.owningApplication?.processID != ProcessInfo.processInfo.processIdentifier,
                  window.frame.width >= 120,
                  window.frame.height >= 80 else { return nil }

            let appName = window.owningApplication?.applicationName ?? "Unknown app"
            let title = (window.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let bundleID = window.owningApplication?.bundleIdentifier?.lowercased() ?? ""
            let searchableName = (appName + " " + bundleID).lowercased()
            guard !excluded.contains(where: { !$0.isEmpty && searchableName.contains($0) }) else { return nil }
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

    func refreshWindows(excludingAppNames: Set<String>) async {
        guard !isLoadingWindows else { return }
        isLoadingWindows = true
        errorMessage = nil
        status = "Finding visible windows…"
        defer { isLoadingWindows = false }
        do {
            windows = try await VerityScreenCaptureService.availableWindows(excludingAppNames: excludingAppNames)
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

    func captureSelected() async {
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
        guard !isAsking, !prompt.isEmpty, !context.isEmpty else { return }

        isAsking = true
        errorMessage = nil
        answer = "Verity is asking NOVA V8…"
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
    @StateObject private var model = VerityScreenContextModel()
    @State private var question = "Explain what I'm looking at and what I should do next."
    @State private var isConfirmingSend = false
    @Environment(\.dismiss) private var dismiss

    private var excludedAppNames: Set<String> {
        Set(excludedAppsRaw.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
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

            Toggle("Allow screen understanding", isOn: $screenContextEnabled)

            if screenContextEnabled {
                HStack(spacing: 8) {
                    Picker("Window", selection: $model.selectedWindowID) {
                        ForEach(model.windows) { window in
                            Text(window.displayTitle).tag(Optional(window.id))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Button(model.isLoadingWindows ? "Loading…" : "Refresh") {
                        Task { await model.refreshWindows(excludingAppNames: excludedAppNames) }
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

                TextField("Ask Verity about this window…", text: $question, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)

                HStack {
                    Text(model.status).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Send reviewed text to NOVA V8") { isConfirmingSend = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isAsking || model.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if model.isAsking {
                    ProgressView("Asking NOVA V8…").controlSize(.small)
                }
                if !model.answer.isEmpty {
                    ScrollView {
                        Text(model.answer)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 70, maxHeight: 120)
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
            if screenContextEnabled {
                await model.refreshWindows(excludingAppNames: excludedAppNames)
            }
        }
        .alert("Send selected screen text to NOVA V8?", isPresented: $isConfirmingSend) {
            Button("Cancel", role: .cancel) {}
            Button("Send reviewed text") {
                model.ask(question: question)
            }
        } message: {
            Text("Only the OCR text shown above and your question are sent. The screenshot itself stays on this Mac. Continue?")
        }
    }
}
