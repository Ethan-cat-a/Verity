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
    @ObservedObject private var model = VerityModel.shared
    @ObservedObject private var updateChecker = VerityUpdateChecker.shared
    @AppStorage(VerityPrivacyPreferences.blindModeEnabledKey) private var blindModeEnabled = false
    @AppStorage(VerityPrivacyPreferences.quietPresenceEnabledKey) private var quietPresenceEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VerityFace(size: 34, mood: .happy)
                VStack(alignment: .leading, spacing: 1) {
                    Text("VERITY")
                        .font(.headline)
                    Text("Your personal helper friend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button {
                VerityPanelController.shared.show()
            } label: {
                Label("Open VERITY · ⌘⇧V", systemImage: "eye")
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Toggle("Blind Mode · pause screen reading", isOn: $blindModeEnabled)
            Toggle("Quiet presence", isOn: $quietPresenceEnabled)

            Button {
                VerityPanelController.shared.hide()
            } label: {
                Label("Hide Verity window", systemImage: "eye.slash")
            }

            Button {
                VerityPanelController.shared.showPetAgain()
            } label: {
                Label("Show desktop helper", systemImage: "pawprint")
            }

            Button {
                VerityPanelController.shared.hidePet()
            } label: {
                Label("Hide desktop helper", systemImage: "eye.slash")
            }

            Button {
                VerityFileActions.openVault()
            } label: {
                Label("Open Verity Vault", systemImage: "shippingbox")
            }

            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }

            if updateChecker.updateAvailable {
                Button {
                    Task { await updateChecker.installAvailableUpdate() }
                } label: {
                    Label(
                        updateChecker.isInstalling ? "Installing VERITY…" : "Update VERITY · \(updateChecker.latestVersion)",
                        systemImage: "arrow.down.circle.fill"
                    )
                }
                .disabled(updateChecker.isInstalling)
            } else {
                Button {
                    Task { await updateChecker.checkNow() }
                } label: {
                    Label(updateChecker.isChecking ? "Checking for updates…" : "Check for updates…", systemImage: "arrow.clockwise")
                }
                .disabled(updateChecker.isChecking)
            }

            if let file = model.lastEatenFileName {
                Text("Last fed: \(file)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Divider()

            Button("Quit VERITY") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 230)
    }
}
