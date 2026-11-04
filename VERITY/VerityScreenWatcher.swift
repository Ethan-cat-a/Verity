import AppKit
import SwiftUI
import ApplicationServices
import Combine
import Vision

@MainActor
final class VerityScreenWatcher: ObservableObject {
    static let shared = VerityScreenWatcher()
    static let enabledKey = "verity.screenAwareness.enabled"
    static let closeExplicitTabsKey = "verity.screenAwareness.closeExplicitTabs"

    @Published private(set) var isWatching = false
    @Published private(set) var status = "Screen awareness is off."

    private var timer: Timer?
    private var lastForegroundApp = ""
    private var lastCommentAt = Date.distantPast
    private var lastInterventionAt = Date.distantPast
    private var interventionInProgress = false

    private init() {
        UserDefaults.standard.register(defaults: [Self.closeExplicitTabsKey: true])
    }

    func startIfEnabled() {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else {
            status = "Screen awareness is off."
            return
        }
        enable()
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        if enabled { enable() } else { disable() }
    }

    func setCloseEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.closeExplicitTabsKey)
        if enabled && UserDefaults.standard.bool(forKey: Self.enabledKey) {
            let trusted = AXIsProcessTrustedWithOptions([
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary)
            status = trusted
                ? "Screen awareness is on. Explicit browser tabs will be blurred, then closed."
                : "Screen checks are on. Allow VERITY under Privacy & Security → Accessibility to enable automatic tab closing."
        }
    }

    private func enable() {
        guard CGPreflightScreenCaptureAccess() else {
            let requested = CGRequestScreenCaptureAccess()
            isWatching = false
            status = requested
                ? "Screen access granted. Restart VERITY to begin watching."
                : "Allow Screen Recording for VERITY in System Settings → Privacy & Security, then restart it."
            return
        }

        isWatching = true
        status = "Watching the active window locally. Nothing is uploaded or saved."
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.inspectForegroundWindow() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }

        if UserDefaults.standard.bool(forKey: Self.closeExplicitTabsKey) {
            let trusted = AXIsProcessTrustedWithOptions([
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary)
            if !trusted {
                status = "Watching locally. Allow VERITY under Privacy & Security → Accessibility to enable tab closing."
            }
        }
    }

    private func disable() {
        timer?.invalidate()
        timer = nil
        isWatching = false
        interventionInProgress = false
        VerityBlurOverlay.shared.hide()
        status = "Screen awareness is off."
    }

    private func inspectForegroundWindow() {
        guard isWatching, !interventionInProgress else { return }
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else { return }

        let appName = app.localizedName ?? bundleID
        guard let window = foregroundWindow(for: app.processIdentifier) else {
            commentOnApplicationChange(appName: appName, bundleID: bundleID)
            return
        }

        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            window.id,
            [.bestResolution]
        ) else { return }

        let recognizedText = recognizeText(in: image)
        let inspectedText = window.title + " " + recognizedText

        if VerityScreenSignals.containsExplicitText(inspectedText),
           VerityScreenSignals.isBrowserBundle(bundleID),
           Date().timeIntervalSince(lastInterventionAt) > 15 {
            lastInterventionAt = Date()
            interveneForExplicitContent(appName: appName)
            return
        }

        commentOnApplicationChange(appName: appName, bundleID: bundleID)
    }

    private func foregroundWindow(for pid: pid_t) -> (id: CGWindowID, title: String)? {
        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for info in rawWindows {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int ?? 1) == 0,
                  let number = info[kCGWindowNumber as String] as? NSNumber else { continue }
            let title = info[kCGWindowName as String] as? String ?? ""
            return (number.uint32Value, title)
        }
        return nil
    }

    private func recognizeText(in image: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.012
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")
        } catch {
            return ""
        }
    }

    private func commentOnApplicationChange(appName: String, bundleID: String) {
        let signature = bundleID + "|" + appName
        guard signature != lastForegroundApp,
              Date().timeIntervalSince(lastCommentAt) > 12 else { return }
        lastForegroundApp = signature
        guard let reaction = VerityScreenSignals.reaction(forApplication: appName) else { return }
        lastCommentAt = Date()
        VerityModel.shared.setStatus(reaction)
        VerityModel.shared.showReaction(.happy, duration: 1_900_000_000)
    }

    private func interveneForExplicitContent(appName: String) {
        guard !interventionInProgress else { return }
        interventionInProgress = true
        lastForegroundApp = ""
        let shouldClose = UserDefaults.standard.bool(forKey: Self.closeExplicitTabsKey)
        let hasAccessibility = AXIsProcessTrusted()

        VerityModel.shared.setStatus(
            shouldClose && hasAccessibility
                ? "Absolutely not. I am blurring that tab, then closing it."
                : "That content is not staying on my watch. I have blurred it."
        )
        VerityModel.shared.showReaction(.shocked, duration: 2_000_000_000)
        VerityBlurOverlay.shared.show(message: "VERITY OBJECTS.")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            if shouldClose && hasAccessibility {
                closeActiveBrowserTab()
            }
            try? await Task.sleep(nanoseconds: 650_000_000)
            VerityBlurOverlay.shared.hide()
            interventionInProgress = false
            status = shouldClose && hasAccessibility
                ? "Explicit browser content blurred and the active tab was closed."
                : (shouldClose ? "Content blurred. Enable Accessibility to allow automatic tab closing." : "Content blurred. Automatic tab closing is disabled.")
            VerityModel.shared.setStatus(
                shouldClose && hasAccessibility
                    ? "There. Tab closed. Try having better taste."
                    : "I blurred that. Enable Accessibility if you want me to close tabs too."
            )
        }
    }

    private func closeActiveBrowserTab() {
        guard AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

@MainActor
private final class VerityBlurOverlay {
    static let shared = VerityBlurOverlay()
    private var panels: [NSPanel] = []

    func show(message: String) {
        hide()
        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: VerityBlurOverlayView(message: message))
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }
}

private struct VerityBlurOverlayView: View {
    let message: String

    var body: some View {
        ZStack {
            ScreenBlurEffect().ignoresSafeArea()
            VStack(spacing: 8) {
                VerityFace(size: 68, mood: .shocked)
                Text(message)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(2)
                Text("I have standards. Apparently you need them.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ScreenBlurEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
