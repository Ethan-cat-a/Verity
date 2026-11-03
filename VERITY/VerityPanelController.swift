import AppKit
import SwiftUI
import Combine

/// Owns the full conversation surface and a fixed, transparent desktop helper.
@MainActor
final class VerityPanelController: ObservableObject {
    static let shared = VerityPanelController()

    private var companionPanel: VerityPanel?
    private var petPanel: VerityPetPanel?
    private let petSize = NSSize(width: 180, height: 180)

    private init() {}

    /// The menu-bar action opens the full assistant window.
    func show() {
        showCompanion()
    }

    /// Creates the helper once and keeps it docked in the lower-right corner.
    /// It is deliberately not a roaming or user-movable desktop pet.
    func showPet() {
        if petPanel == nil {
            let panel = VerityPetPanel(
                contentRect: NSRect(origin: .zero, size: petSize),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: VerityDesktopPetView())
            panel.setFrameOrigin(initialPetOrigin(for: petSize))
            petPanel = panel
        }

        petPanel?.orderFrontRegardless()
    }

    /// Opens the larger conversation and document surface when the helper is clicked.
    func showCompanion() {
        if companionPanel == nil {
            let size = NSSize(width: 380, height: 560)
            let panel = VerityPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = NSHostingView(rootView: VerityDesktopView())
            panel.setFrameOrigin(initialCompanionOrigin(for: size))
            companionPanel = panel
        }

        companionPanel?.orderFrontRegardless()
    }

    /// Hides only the larger interaction window; the small helper remains visible.
    func hide() {
        companionPanel?.orderOut(nil)
    }

    func hidePet() {
        petPanel?.orderOut(nil)
    }

    func showPetAgain() {
        showPet()
    }

    private func initialPetOrigin(for size: NSSize) -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return NSPoint(x: frame.maxX - size.width - 22, y: frame.minY + 64)
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
