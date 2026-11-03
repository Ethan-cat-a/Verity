import Foundation
import AppKit
import UniformTypeIdentifiers

/// Loads a Finder file URL from an NSItemProvider supplied by SwiftUI's onDrop.
enum FileDropHandler {
    static func handle(_ providers: [NSItemProvider], completion: @escaping (URL?) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            completion(nil)
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?

            if let receivedURL = item as? URL {
                url = receivedURL
            } else if let receivedURL = item as? NSURL {
                url = receivedURL as URL
            } else if let data = item as? Data,
                      let string = String(data: data, encoding: .utf8),
                      let parsedURL = URL(string: string) {
                url = parsedURL
            } else if let string = item as? String, let parsedURL = URL(string: string) {
                url = parsedURL
            } else {
                url = nil
            }

            completion(url?.isFileURL == true ? url : nil)
        }

        return true
    }
}
