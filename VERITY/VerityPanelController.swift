import AppKit
import SwiftUI
import Combine

/// Owns the full conversation surface and the separate transparent desktop pet.
@MainActor
final class VerityPanelController: ObservableObject {
    static let shared = VerityPanelController()

    private var companionPanel: VerityPanel?
    private var petPanel: VerityPetPanel?
    private var wanderingTask: Task<Void, Never>?
    private var isWanderingPaused = false
    private let petSize = NSSize(width: 180, height: 180)
    private let edgePadding: CGFloat = 8

    @Published private(set) var rollAngle = 0.0

    private init() {}

    /// Kept as the normal menu action: open the full Verity window.
    func show() {
        showCompanion()
    }

    func showPet() {
        if petPanel == nil {
            let newPanel = VerityPetPanel(
                contentRect: NSRect(origin: .zero, size: petSize),
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
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.contentView = NSHostingView(rootView: VerityDesktopPetView())
            newPanel.setFrameOrigin(initialPetOrigin(for: petSize))
            petPanel = newPanel
        }

        petPanel?.orderFrontRegardless()
        isWanderingPaused = false
        startWanderingIfNeeded()
    }

    func showCompanion() {
        if companionPanel == nil {
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
            newPanel.isMovableByWindowBackground = true
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            newPanel.contentView = NSHostingView(rootView: VerityDesktopView())
            newPanel.setFrameOrigin(initialCompanionOrigin(for: size))
            companionPanel = newPanel
        }

        isWanderingPaused = true
        companionPanel?.orderFrontRegardless()
    }

    /// Hides only the larger interaction window; the little desktop pet stays.
    func hide() {
        companionPanel?.orderOut(nil)
        isWanderingPaused = false
    }

    func hidePet() {
        isWanderingPaused = true
        petPanel?.orderOut(nil)
    }

    func showPetAgain() {
        showPet()
    }

    func beginUserDrag() {
        isWanderingPaused = true
    }

    func endUserDrag() {
        isWanderingPaused = false
    }

    func dragPet(by translation: CGSize) {
        guard let petPanel else { return }
        var frame = petPanel.frame
        let bounds = screenForFrame(frame).visibleFrame.insetBy(dx: edgePadding, dy: edgePadding)
        let targetX = frame.origin.x + translation.width
        let targetY = frame.origin.y - translation.height
        frame.origin = clampedOrigin(x: targetX, y: targetY, frameSize: frame.size, inside: bounds)
        petPanel.setFrame(frame, display: true)
        rollAngle += Double(translation.width * 0.60 - translation.height * 0.28)
    }

    private func startWanderingIfNeeded() {
        guard wanderingTask == nil else { return }
        wanderingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 11...22) * 1_000_000_000)
                guard let self, !Task.isCancelled else { break }
                guard !self.isWanderingPaused,
                      let petPanel = self.petPanel,
                      petPanel.isVisible else { continue }
                self.rollToAnotherSpot(petPanel)
            }
        }
    }

    /// Moves the invisible pet window across the usable desktop on any display.
    private func rollToAnotherSpot(_ petPanel: NSPanel) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let screen = screens.randomElement() ?? screens[0]
        let bounds = screen.visibleFrame.insetBy(dx: edgePadding, dy: edgePadding)
        let maxX = max(bounds.minX, bounds.maxX - petPanel.frame.width)
        let maxY = max(bounds.minY, bounds.maxY - petPanel.frame.height)
        let destination = NSRect(
            x: CGFloat.random(in: bounds.minX...maxX),
            y: CGFloat.random(in: bounds.minY...maxY),
            width: petPanel.frame.width,
            height: petPanel.frame.height
        )

        rollAngle += 360
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Double.random(in: 2.0...3.2)
            petPanel.animator().setFrame(destination, display: true)
        }
    }

    private func screenForFrame(_ frame: NSRect) -> NSScreen {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first(where: { $0.visibleFrame.contains(center) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func clampedOrigin(x: CGFloat, y: CGFloat, frameSize: NSSize, inside bounds: NSRect) -> NSPoint {
        let maxX = max(bounds.minX, bounds.maxX - frameSize.width)
        let maxY = max(bounds.minY, bounds.maxY - frameSize.height)
        return NSPoint(
            x: min(max(x, bounds.minX), maxX),
            y: min(max(y, bounds.minY), maxY)
        )
    }

    private func initialPetOrigin(for size: NSSize) -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return NSPoint(x: frame.maxX - size.width - 24, y: frame.maxY - size.height - 80)
    }

    private func initialCompanionOrigin(for size: NSSize) -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return NSPoint(x: frame.maxX - size.width - 28, y: frame.maxY - size.height - 36)
    }
}

private final class VerityPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class VerityPetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
