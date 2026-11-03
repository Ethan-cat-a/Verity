import AppKit
import SwiftUI
import Combine

@MainActor
final class VerityPanelController: ObservableObject {
    static let shared = VerityPanelController()

    private var panel: VerityPanel?
    private var wanderingTask: Task<Void, Never>?
    private var isWanderingPaused = false
    private let edgePadding: CGFloat = 16
    @Published private(set) var rollAngle = 0.0

    private init() {}

    func show() {
        if panel == nil {
            let size = NSSize(width: 380, height: 560)
            let newPanel = VerityPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = false
            newPanel.hidesOnDeactivate = false
            newPanel.isMovableByWindowBackground = false
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            newPanel.contentView = NSHostingView(rootView: VerityDesktopView())
            newPanel.setFrameOrigin(initialOrigin(for: size))
            panel = newPanel
        }
        isWanderingPaused = false
        panel?.orderFrontRegardless()
        startWanderingIfNeeded()
    }

    func hide() {
        isWanderingPaused = true
        panel?.orderOut(nil)
    }

    func setWanderingPaused(_ paused: Bool) { isWanderingPaused = paused }
    func beginUserDrag() { isWanderingPaused = true }
    func endUserDrag() { isWanderingPaused = false }

    func dragPanel(by translation: CGSize) {
        guard let panel else { return }
        var frame = panel.frame
        let bounds = screenForPanel(frame).visibleFrame.insetBy(dx: edgePadding, dy: edgePadding)
        let proposedX = frame.origin.x + translation.width
        let proposedY = frame.origin.y - translation.height
        frame.origin = clampedOrigin(x: proposedX, y: proposedY, frameSize: frame.size, inside: bounds)
        panel.setFrame(frame, display: true)
        rollAngle += Double(translation.width * 0.45 - translation.height * 0.20)
    }

    private func startWanderingIfNeeded() {
        guard wanderingTask == nil else { return }
        wanderingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 10...18) * 1_000_000_000)
                guard let self, !Task.isCancelled else { break }
                guard !self.isWanderingPaused, let panel = self.panel, panel.isVisible else { continue }
                self.wanderToAnotherSpot(panel)
            }
        }
    }

    private func wanderToAnotherSpot(_ panel: NSPanel) {
        let bounds = screenForPanel(panel.frame).visibleFrame.insetBy(dx: edgePadding, dy: edgePadding)
        let minX = bounds.minX
        let minY = bounds.minY
        let maxX = max(minX, bounds.maxX - panel.frame.width)
        let maxY = max(minY, bounds.maxY - panel.frame.height)
        let destination = NSRect(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY),
            width: panel.frame.width,
            height: panel.frame.height
        )
        rollAngle += 360
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 2.7
            panel.animator().setFrame(destination, display: true)
        }
    }

    private func screenForPanel(_ frame: NSRect) -> NSScreen {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first(where: { $0.visibleFrame.contains(center) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func clampedOrigin(x: CGFloat, y: CGFloat, frameSize: NSSize, inside bounds: NSRect) -> NSPoint {
        let maxX = max(bounds.minX, bounds.maxX - frameSize.width)
        let maxY = max(bounds.minY, bounds.maxY - frameSize.height)
        return NSPoint(x: min(max(x, bounds.minX), maxX), y: min(max(y, bounds.minY), maxY))
    }

    private func initialOrigin(for size: NSSize) -> NSPoint {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return NSPoint(x: visibleFrame.maxX - size.width - 28, y: visibleFrame.maxY - size.height - 36)
    }
}

private final class VerityPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
