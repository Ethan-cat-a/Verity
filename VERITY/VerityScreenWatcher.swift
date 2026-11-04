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
    static let schoolHoursGamingGuardEnabledKey = "verity.screenAwareness.schoolHoursGamingGuardEnabled"

    @Published private(set) var isWatching = false
    @Published private(set) var status = "Screen awareness is off."
    @Published private(set) var lastScanSummary = "No screen check has run yet."
    @Published private(set) var lastScanAt: Date?

    private var timer: Timer?
    private var lastForegroundApp = ""
    private var lastCommentAt = Date.distantPast
    private var lastInterventionAt = Date.distantPast
    private var lastSchoolGamingInterventionAt = Date.distantPast
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

    /// Runs a one-off check from Settings and retries setup after permissions
    /// have been changed in System Settings.
    func runCheckNow() {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else {
            lastScanAt = Date()
            lastScanSummary = "Turn on screen awareness first."
            status = "Screen awareness is off."
            return
        }

        if !CGPreflightScreenCaptureAccess() {
            enable()
            lastScanAt = Date()
            lastScanSummary = "Screen Recording permission is not active. Grant it, fully quit VERITY, and reopen it."
            return
        }

        if !isWatching {
            enable()
        }
        guard isWatching else {
            lastScanAt = Date()
            lastScanSummary = status
            return
        }

        inspectForegroundWindow()
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

    func setSchoolHoursGamingGuardEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.schoolHoursGamingGuardEnabledKey)
        guard enabled, UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }

        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)
        status = trusted
            ? "School-hours gaming guard is on. Weekdays, 08:00–15:30."
            : "School-hours game checks are on. Allow VERITY under Privacy & Security → Accessibility so it can close games."
    }

    private func enable() {
        guard CGPreflightScreenCaptureAccess() else {
            // Verify access separately; the request result does not guarantee that
            // this process can capture immediately.
            _ = CGRequestScreenCaptureAccess()
            timer?.invalidate()
            timer = nil
            isWatching = false
            status = "Screen Recording permission is not active yet. Allow VERITY in System Settings → Privacy & Security → Screen Recording, then fully quit and reopen VERITY."
            lastScanSummary = status
            return
        }

        guard !isWatching || timer == nil else {
            status = "Screen awareness is active. Checking the frontmost window every six seconds."
            return
        }

        isWatching = true
        status = "Screen awareness is active. Checking the frontmost window every six seconds."
        timer?.invalidate()

        let scanTimer = Timer(timeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.inspectForegroundWindow() }
        }
        timer = scanTimer
        RunLoop.main.add(scanTimer, forMode: .common)

        let closeNeedsAccessibility =
            UserDefaults.standard.bool(forKey: Self.closeExplicitTabsKey) ||
            UserDefaults.standard.bool(forKey: Self.schoolHoursGamingGuardEnabledKey)
        if closeNeedsAccessibility {
            let trusted = AXIsProcessTrustedWithOptions([
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary)
            if !trusted {
                status = "Screen checks are active. Allow VERITY under Privacy & Security → Accessibility to enable automatic tab/game closing."
            }
        }

        inspectForegroundWindow()
    }

    private func disable() {
        timer?.invalidate()
        timer = nil
        isWatching = false
        interventionInProgress = false
        VerityBlurOverlay.shared.hide()
        VerityCommentBubble.shared.hide()
        status = "Screen awareness is off."
        lastScanSummary = "Screen awareness is off."
    }

    private func inspectForegroundWindow() {
        guard isWatching else {
            recordScan("Screen awareness is not running.")
            return
        }
        guard !interventionInProgress else { return }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            recordScan("No frontmost application was found.")
            return
        }
        guard let bundleID = app.bundleIdentifier else {
            recordScan("The frontmost application has no bundle identifier.")
            return
        }

        let appName = app.localizedName ?? bundleID
        guard bundleID != Bundle.main.bundleIdentifier else {
            recordScan("VERITY is currently frontmost. Switch to a browser or game app to test detection.")
            return
        }

        guard let window = foregroundWindow(for: app.processIdentifier) else {
            commentOnApplicationChange(appName: appName, bundleID: bundleID)
            recordScan("Found \(appName), but macOS did not report an inspectable frontmost window.")
            return
        }

        // A native game is recognizable from the foreground application identity.
        // Check it before requesting an image so a screenshot failure cannot block it.
        if UserDefaults.standard.bool(forKey: Self.schoolHoursGamingGuardEnabledKey),
           isSchoolHoursNow(),
           !VerityScreenSignals.isBrowserBundle(bundleID),
           let gamingTarget = VerityScreenSignals.schoolHoursGamingTarget(
                appName: appName,
                bundleID: bundleID,
                windowTitle: window.title,
                visibleText: ""
           ),
           Date().timeIntervalSince(lastSchoolGamingInterventionAt) > 45 {
            lastSchoolGamingInterventionAt = Date()
            recordScan("Detected game app: \(appName). Starting school-hours reaction.")
            interveneForSchoolGaming(target: gamingTarget, bundleID: bundleID, windowID: window.id)
            return
        }

        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            window.id,
            [.bestResolution]
        ) else {
            commentOnApplicationChange(appName: appName, bundleID: bundleID)
            recordScan("Found \(appName), but macOS did not provide a screenshot. Check Screen Recording permission.")
            return
        }

        let recognizedText = recognizeText(in: image)
        let inspectedText = window.title + " " + recognizedText

        if UserDefaults.standard.bool(forKey: Self.schoolHoursGamingGuardEnabledKey),
           isSchoolHoursNow(),
           let gamingTarget = VerityScreenSignals.schoolHoursGamingTarget(
                appName: appName,
                bundleID: bundleID,
                windowTitle: window.title,
                visibleText: recognizedText
           ),
           Date().timeIntervalSince(lastSchoolGamingInterventionAt) > 45 {
            lastSchoolGamingInterventionAt = Date()
            recordScan("Detected gaming page/app: \(appName). Starting school-hours reaction.")
            interveneForSchoolGaming(target: gamingTarget, bundleID: bundleID, windowID: window.id)
            return
        }

        if VerityScreenSignals.containsExplicitText(inspectedText),
           VerityScreenSignals.isBrowserBundle(bundleID),
           Date().timeIntervalSince(lastInterventionAt) > 15 {
            lastInterventionAt = Date()
            recordScan("Detected an explicit-content text signal in \(appName).")
            interveneForExplicitContent(bundleID: bundleID, windowID: window.id)
            return
        }

        commentOnApplicationChange(appName: appName, bundleID: bundleID)
        if VerityScreenSignals.isBrowserBundle(bundleID) {
            recordScan("Checked \(appName) and read visible text. No configured screen trigger was found.")
        } else {
            recordScan("Checked foreground app: \(appName). No configured screen trigger was found.")
        }
    }

    private func recordScan(_ summary: String) {
        lastScanAt = Date()
        lastScanSummary = summary
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
        VerityCommentBubble.shared.show(message: reaction)
    }

    private func interveneForExplicitContent(bundleID: String, windowID: CGWindowID) {
        guard !interventionInProgress else { return }
        interventionInProgress = true
        lastForegroundApp = ""

        let closeWasEnabled = UserDefaults.standard.bool(forKey: Self.closeExplicitTabsKey)
        let hasAccessibility = AXIsProcessTrusted()
        VerityModel.shared.setStatus(
            closeWasEnabled && hasAccessibility
                ? "Absolutely not. I am blurring that tab, then checking it again before closing."
                : "That content is not staying on my watch. I have blurred it."
        )
        VerityModel.shared.showReaction(.shocked, duration: 2_000_000_000)
        VerityBlurOverlay.shared.show(message: "VERITY OBJECTS.")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)

            guard isWatching else {
                VerityBlurOverlay.shared.hide()
                VerityCommentBubble.shared.hide()
                interventionInProgress = false
                return
            }

            // Re-check the foreground app, exact window and visible text immediately
            // before sending Command-W. A quick app/tab switch must never close a
            // different page or window.
            let closeStillEnabled = UserDefaults.standard.bool(forKey: Self.closeExplicitTabsKey)
            let didClose = closeStillEnabled &&
                AXIsProcessTrusted() &&
                frontmostWindowStillShowsExplicitContent(bundleID: bundleID, windowID: windowID)

            if didClose {
                closeActiveBrowserTab()
            }

            try? await Task.sleep(nanoseconds: 650_000_000)
            VerityBlurOverlay.shared.hide()
            interventionInProgress = false

            if didClose {
                status = "Explicit browser content blurred and the same tab was closed."
            } else if !closeStillEnabled {
                status = "Content blurred. Automatic tab closing is disabled."
            } else if !AXIsProcessTrusted() {
                status = "Content blurred. Enable Accessibility to allow automatic tab closing."
            } else {
                status = "Content blurred. The active page changed, so VERITY left it alone."
            }

            let finalComment = didClose
                ? "There. Tab closed. Try having better taste."
                : (closeStillEnabled
                    ? "I blurred that. The page changed, so I left the new one alone."
                    : "I blurred that. Closing is disabled.")
            VerityModel.shared.setStatus(finalComment)
            VerityCommentBubble.shared.show(message: finalComment)
        }
    }


    private func isSchoolHoursNow() -> Bool {
        let parts = Calendar.autoupdatingCurrent.dateComponents(
            [.weekday, .hour, .minute],
            from: Date()
        )
        return VerityScreenSignals.isSchoolHours(
            weekday: parts.weekday ?? 0,
            hour: parts.hour ?? -1,
            minute: parts.minute ?? -1
        )
    }

    private func interveneForSchoolGaming(
        target: VerityScreenSignals.GamingTarget,
        bundleID: String,
        windowID: CGWindowID
    ) {
        guard !interventionInProgress else { return }
        interventionInProgress = true
        lastForegroundApp = ""

        let targetName: String
        let actionDescription: String
        switch target {
        case .browserSite(let site):
            targetName = site
            actionDescription = "closing that tab"
        case .application(let app):
            targetName = app
            actionDescription = "quitting that game"
        }

        let scolding = "You're gaming during class? Embarrassing. \(targetName) can wait. I'm \(actionDescription). Back to work."
        VerityModel.shared.setStatus(scolding)
        VerityModel.shared.showReaction(.angry, duration: 2_800_000_000)
        VerityBlurOverlay.shared.show(message: "CLASS TIME. GAME TIME IS OVER.")
        VerityCommentBubble.shared.show(message: scolding)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)

            guard isWatching else {
                VerityBlurOverlay.shared.hide()
                VerityCommentBubble.shared.hide()
                interventionInProgress = false
                return
            }

            let guardStillEnabled = UserDefaults.standard.bool(forKey: Self.schoolHoursGamingGuardEnabledKey)
            let stillSchoolHours = isSchoolHoursNow()
            let hasAccessibility = AXIsProcessTrusted()
            let sameGamingTarget = frontmostWindowStillShowsGamingTarget(
                target: target,
                bundleID: bundleID,
                windowID: windowID
            )
            let didClose = guardStillEnabled && stillSchoolHours && hasAccessibility && sameGamingTarget

            if didClose {
                switch target {
                case .browserSite(_):
                    closeActiveBrowserTab()
                case .application(_):
                    quitActiveGameApplication()
                }
            }

            try? await Task.sleep(nanoseconds: 650_000_000)
            VerityBlurOverlay.shared.hide()
            interventionInProgress = false

            let finalComment: String
            if didClose {
                switch target {
                case .browserSite(_):
                    finalComment = "\(targetName) tab closed. Now get back to class."
                case .application(_):
                    finalComment = "\(targetName) was quit. Now get back to class."
                }
            } else if !guardStillEnabled {
                finalComment = "School-hours guard is off. I left it alone."
            } else if !stillSchoolHours {
                finalComment = "School hours are over. I left the game alone."
            } else if !hasAccessibility {
                finalComment = "Game spotted. Allow VERITY under Privacy & Security → Accessibility so I can close it."
            } else {
                finalComment = "You changed pages or apps, so I left the new one alone."
            }

            VerityModel.shared.setStatus(finalComment)
            VerityCommentBubble.shared.show(message: finalComment)
        }
    }

    private func frontmostWindowStillShowsGamingTarget(
        target: VerityScreenSignals.GamingTarget,
        bundleID: String,
        windowID: CGWindowID
    ) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == bundleID,
              let window = foregroundWindow(for: app.processIdentifier),
              window.id == windowID else { return false }

        switch target {
        case .browserSite:
            guard VerityScreenSignals.isBrowserBundle(bundleID),
                  let image = CGWindowListCreateImage(
                    .null,
                    .optionIncludingWindow,
                    windowID,
                    [.bestResolution]
                  ) else { return false }
            let visibleText = recognizeText(in: image)
            return VerityScreenSignals.schoolHoursGamingTarget(
                appName: app.localizedName ?? bundleID,
                bundleID: bundleID,
                windowTitle: window.title,
                visibleText: visibleText
            ) == target

        case .application:
            return VerityScreenSignals.schoolHoursGamingTarget(
                appName: app.localizedName ?? bundleID,
                bundleID: bundleID,
                windowTitle: window.title,
                visibleText: ""
            ) == target
        }
    }

    private func frontmostWindowStillShowsExplicitContent(bundleID: String, windowID: CGWindowID) -> Bool {
        guard VerityScreenSignals.isBrowserBundle(bundleID),
              let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == bundleID,
              let window = foregroundWindow(for: app.processIdentifier),
              window.id == windowID,
              let image = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.bestResolution]
              ) else { return false }

        let visibleText = window.title + " " + recognizeText(in: image)
        return VerityScreenSignals.containsExplicitText(visibleText)
    }

    private func closeActiveBrowserTab() {
        postCommandKey(virtualKey: 0x0D) // W
    }

    /// Browser games are closed with Command-W; native game apps use Command-Q.
    /// This is a normal app quit, not a force-quit, so the app can handle its own exit.
    private func quitActiveGameApplication() {
        guard AXIsProcessTrusted() else { return }
        postCommandKey(virtualKey: 0x0C) // Q
    }

    private func postCommandKey(virtualKey: CGKeyCode) {
        guard AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

@MainActor
private final class VerityCommentBubble {
    static let shared = VerityCommentBubble()
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?

    func show(message: String) {
        guard let screen = NSScreen.main else { return }
        dismissalTask?.cancel()

        let size = NSSize(width: 320, height: 92)
        let frame = screen.visibleFrame
        let origin = NSPoint(x: frame.maxX - size.width - 22, y: frame.minY + 246)
        let windowFrame = NSRect(origin: origin, size: size)

        if panel == nil {
            let bubble = NSPanel(
                contentRect: windowFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            bubble.isFloatingPanel = true
            bubble.level = .floating
            bubble.isOpaque = false
            bubble.backgroundColor = .clear
            bubble.ignoresMouseEvents = true
            bubble.hidesOnDeactivate = false
            bubble.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel = bubble
        }

        panel?.contentView = NSHostingView(rootView: VerityCommentBubbleView(message: message))
        panel?.setFrame(windowFrame, display: true)
        panel?.orderFrontRegardless()

        dismissalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_800_000_000)
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
        }
    }

    func hide() {
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
    }
}

private struct VerityCommentBubbleView: View {
    let message: String

    var body: some View {
        HStack(spacing: 11) {
            VerityFace(size: 46, mood: .happy)
            Text(message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(width: 320, height: 92)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 14, y: 7)
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
