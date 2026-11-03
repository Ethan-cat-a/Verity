import Foundation
import AppKit
import Combine

/// Verity's autonomous snack gag. It reads filenames from the user's Trash only.
/// The selected item is never opened, moved, restored, renamed, or deleted.
@MainActor
final class VerityPetLifeModel: ObservableObject {
    static let trashSnacksPreferenceKey = "verity.trashSnacksEnabled"
    static let eerieIdlePreferenceKey = "verity.eerieIdleEnabled"

    @Published private(set) var hungerLevel = 0.0
    private var hungerTask: Task<Void, Never>?

    func start() {
        guard hungerTask == nil else { return }
        hungerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 22_000_000_000)
                guard let self else { return }
                let enabled = UserDefaults.standard.object(forKey: Self.trashSnacksPreferenceKey) as? Bool ?? true
                guard enabled else {
                    self.hungerLevel = 0
                    continue
                }
                guard VerityModel.shared.currentFile == nil, !VerityModel.shared.isEating else { continue }
                self.hungerLevel = min(1.0, self.hungerLevel + Double.random(in: 0.11...0.18))
                if self.hungerLevel >= 1.0 {
                    self.hungerLevel = 0
                    self.tryTrashSnack()
                }
            }
        }
    }

    private func tryTrashSnack() {
        let trashURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash", isDirectory: true)
        do {
            // Only list names in the user's home Trash. No file contents are read.
            let items = try FileManager.default.contentsOfDirectory(
                at: trashURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            let candidates = items.filter {
                let name = $0.lastPathComponent
                return !name.isEmpty && name != ".DS_Store" && !name.hasPrefix("._")
            }
            guard let snack = candidates.randomElement() else {
                VerityModel.shared.setStatus("Hmm, no snacks in here. Maybe next time!")
                VerityModel.shared.showReaction(.suspicious, duration: 1_400_000_000)
                return
            }

            let name = snack.lastPathComponent
            VerityModel.shared.lastEatenFileName = name
            VerityModel.shared.statusMessage = "Oh! I found \(name). Don't worry, I only looked at the name."
            VerityModel.shared.isEating = true
            VerityModel.shared.setMood(.eating)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_250_000_000)
                guard VerityModel.shared.isEating else { return }
                VerityModel.shared.isEating = false
                VerityModel.shared.setMood(.happy)
                VerityModel.shared.statusMessage = "All done! Your file is still right where you left it."
            }
        } catch {
            VerityModel.shared.setStatus("I couldn't peek at the Trash, but that's okay!")
            VerityModel.shared.showReaction(.suspicious, duration: 2_000_000_000)
        }
    }
}
