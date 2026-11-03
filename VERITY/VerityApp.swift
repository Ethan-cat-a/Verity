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
            VerityPanelController.shared.show()
        }
    }
}

struct VerityMenuBarView: View {
    @ObservedObject private var model = VerityModel.shared

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
                Label("Show Verity", systemImage: "eye")
            }

            Button {
                VerityPanelController.shared.hide()
            } label: {
                Label("Hide Verity", systemImage: "eye.slash")
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
