import SwiftUI
import AppKit

@main
struct VerityApp: App {
    @NSApplicationDelegateAdaptor(VerityAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("VERITY", systemImage: "face.smiling") {
            VerityMenuBarView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            VeritySettingsView()
        }
    }
}

final class VerityAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            VerityUpdateChecker.shared.startAutomaticChecks()
            VerityPanelController.shared.showPet()
        }
    }
}

struct VerityMenuBarView: View {
    @ObservedObject private var updateChecker = VerityUpdateChecker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VerityFace(size: 38, mood: .happy)
                VStack(alignment: .leading, spacing: 1) {
                    Text("VERITY").font(.headline)
                    Text("The know-it-all ball.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button {
                VerityPanelController.shared.show()
            } label: {
                Label("Ask Verity · ⌘⇧V", systemImage: "bubble.left.and.bubble.right")
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Button {
                VerityPanelController.shared.showPetAgain()
            } label: {
                Label("Show desktop ball", systemImage: "face.smiling")
            }

            Button {
                VerityPanelController.shared.hidePet()
            } label: {
                Label("Hide desktop ball", systemImage: "eye.slash")
            }

            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }

            Divider()

            if updateChecker.updateAvailable {
                Button {
                    Task { await updateChecker.installAvailableUpdate() }
                } label: {
                    Label(
                        updateChecker.isInstalling ? "Installing…" : "Update VERITY · \(updateChecker.latestVersion)",
                        systemImage: "arrow.down.circle.fill"
                    )
                }
                .disabled(updateChecker.isInstalling)
            } else {
                Button {
                    Task { await updateChecker.checkNow() }
                } label: {
                    Label(updateChecker.isChecking ? "Checking…" : "Check for updates", systemImage: "arrow.clockwise")
                }
                .disabled(updateChecker.isChecking)
            }

            Button("Quit VERITY") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 230)
    }
}
