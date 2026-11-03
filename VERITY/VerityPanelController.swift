import AppKit
import SwiftUI

@MainActor
final class VerityPanelController {
    static let shared = VerityPanelController()

    private var panel: VerityPanel?

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
            newPanel.isMovableByWindowBackground = true
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            newPanel.contentView = NSHostingView(rootView: VerityDesktopView())
            newPanel.setFrameOrigin(initialOrigin(for: size))
            panel = newPanel
        }

        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func initialOrigin(for size: NSSize) -> NSPoint {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return NSPoint(
            x: visibleFrame.maxX - size.width - 28,
            y: visibleFrame.maxY - size.height - 36
        )
    }
}

private final class VerityPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
