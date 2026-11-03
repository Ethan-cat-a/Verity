import AppKit
import SwiftUI
import Combine
import QuartzCore

/// Owns the full conversation surface and the separate transparent desktop pet.
@MainActor
final class VerityPanelController: ObservableObject {
    static let shared = VerityPanelController()

    private var companionPanel: VerityPanel?
    private var petPanel: VerityPetPanel?
    private var wanderingTask: Task<Void, Never>?
    private var inertiaTask: Task<Void, Never>?
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
        inertiaTask?.cancel()
        inertiaTask = nil
        isWanderingPaused = true
    }

    func endUserDrag(withVelocity velocity: CGSize = .zero) {
        isWanderingPaused = false
        startInertia(withVelocity: velocity)
    }

    func dragPet(by translation: CGSize) {
        guard let petPanel else { return }
        var frame = petPanel.frame
        let bounds = screenForFrame(frame).visibleFrame.insetBy(dx: edgePadding, dy: edgePadding)
        let targetX = frame.origin.x + translation.width
        let targetY = frame.origin.y - translation.height
        frame.origin = clampedOrigin(x: targetX, y: targetY, frameSize: frame.size, inside: bounds)
        petPanel.setFrame(frame, display: true)
        let radius = max(1.0, petSize.width * 0.34)
        rollAngle += Double(translation.width - translation.height * 0.22) / Double(radius) * 180 / .pi
    }

    private func startWanderingIfNeeded() {
        guard wanderingTask == nil else { return }
        wanderingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 8...15) * 1_000_000_000)
                guard let self, !Task.isCancelled else { break }
                guard !self.isWanderingPaused,
                      let petPanel = self.petPanel,
                      petPanel.isVisible else { continue }
                self.rollToAnotherSpot(petPanel)
            }
        }
    }

    /// A small, eased, curved roll on the current display—never a random display teleport.
    private func rollToAnotherSpot(_ petPanel: NSPanel) {
        let currentScreen = screenForFrame(petPanel.frame)
        let bounds = currentScreen.visibleFrame.insetBy(dx: edgePadding + 12, dy: edgePadding + 12)
        let start = petPanel.frame.origin
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let travel = CGFloat.random(in: 190...430)
        let rawDestination = NSPoint(
            x: start.x + cos(angle) * travel,
            y: start.y + sin(angle) * travel
        )
        let destination = clampedOrigin(
            x: rawDestination.x,
            y: rawDestination.y,
            frameSize: petPanel.frame.size,
            inside: bounds
        )
        let dx = destination.x - start.x
        let dy = destination.y - start.y
        let distance = hypot(dx, dy)
        guard distance > 40 else { return }

        // A small perpendicular offset makes the route feel less like a screensaver glide.
        let bend = CGFloat.random(in: -34...34)
        let midpoint = NSPoint(
            x: start.x + dx * 0.5 - (dy / distance) * bend,
            y: start.y + dy * 0.5 + (dx / distance) * bend
        )
        let control = clampedOrigin(
            x: midpoint.x,
            y: midpoint.y,
            frameSize: petPanel.frame.size,
            inside: bounds
        )
        let speed = CGFloat.random(in: 115...165)
        let duration = Double(distance / speed)
        let radius = max(1.0, petSize.width * 0.34)
        let rotationDirection = abs(dx) >= abs(dy) ? (dx >= 0 ? 1.0 : -1.0) : (dy >= 0 ? -1.0 : 1.0)
        rollAngle += rotationDirection * Double(distance / radius) * 180 / .pi

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = max(0.55, duration * 0.48)
            context.timingFunction = CAMediaTimingFunction(controlPoint: 0.22, 0.72, 0.25, 1.0)
            petPanel.animator().setFrameOrigin(control)
        }, completionHandler: { [weak self, weak petPanel] in
            Task { @MainActor in
                guard let self, let petPanel, !self.isWanderingPaused, petPanel.isVisible else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = max(0.55, duration * 0.52)
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    petPanel.animator().setFrameOrigin(destination)
                }
            }
        })
    }

    /// Adds a short, damped roll after a fast drag so the ball has believable inertia.
    private func startInertia(withVelocity velocity: CGSize) {
        let initialSpeed = hypot(velocity.width, velocity.height)
        guard initialSpeed > 220, let petPanel, petPanel.isVisible else { return }
        let scale = min(1.0, 1050.0 / initialSpeed)
        var vx = velocity.width * scale
        var vy = -velocity.height * scale
        let frameInterval = 0.016
        let radius = max(1.0, petSize.width * 0.34)

        inertiaTask?.cancel()
        inertiaTask = Task { @MainActor [weak self, weak petPanel] in
            guard let self, let petPanel else { return }
            var elapsed = 0.0
            while elapsed < 0.9 && !Task.isCancelled && !self.isWanderingPaused {
                var frame = petPanel.frame
                let bounds = self.screenForFrame(frame).visibleFrame.insetBy(dx: self.edgePadding, dy: self.edgePadding)
                let proposedX = frame.origin.x + vx * frameInterval
                let proposedY = frame.origin.y + vy * frameInterval
                let maxX = max(bounds.minX, bounds.maxX - frame.width)
                let maxY = max(bounds.minY, bounds.maxY - frame.height)
                if proposedX < bounds.minX || proposedX > maxX { vx *= -0.28 }
                if proposedY < bounds.minY || proposedY > maxY { vy *= -0.28 }
                frame.origin = self.clampedOrigin(x: proposedX, y: proposedY, frameSize: frame.size, inside: bounds)
                petPanel.setFrame(frame, display: true)
                self.rollAngle += Double(vx * frameInterval) / Double(radius) * 180 / .pi
                vx *= 0.90
                vy *= 0.90
                elapsed += frameInterval
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            self.inertiaTask = nil
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
