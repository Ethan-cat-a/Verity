import SwiftUI
import AppKit
import PDFKit

struct VerityFileInspectorView: View {
    let file: VerityFile
    let onClose: () -> Void

    @State private var activeSheet: InspectorSheet?
    @State private var actionMessage = ""
    @State private var isShowingTrashConfirmation = false

    private var canUnderstand: Bool {
        VerityNovaClient.supportedExtensions.contains(file.url.pathExtension.lowercased())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 27, height: 27)
                        .background(.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("VERITY ATE SOMETHING")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                fileIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Text("\(file.fileExtension)  •  \(file.sizeDescription)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))

            Text("What should I do with it?")
                .font(.system(size: 13, weight: .bold, design: .rounded))

            VStack(spacing: 6) {
                if canUnderstand {
                    actionButton("Understand with Verity", subtitle: "Summaries, key points and document Q&A", icon: "sparkles") {
                        activeSheet = .assistant
                    }
                }

                actionButton("Read / preview", subtitle: "Extract selectable text where supported", icon: "doc.text.magnifyingglass") {
                    loadPreview()
                }

                actionButton("Keep a copy in Verity Vault", subtitle: "Copies it without deleting the original", icon: "shippingbox") {
                    saveToVault()
                }

                actionButton("Show in Finder", subtitle: "Reveal the original file", icon: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                    actionMessage = "There it is. I didn't move it."
                }

                actionButton("Move to Trash…", subtitle: "Only after you confirm", icon: "trash", isDestructive: true) {
                    isShowingTrashConfirmation = true
                }
            }

            if !actionMessage.isEmpty {
                Text(actionMessage)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text("Your original stays put unless you explicitly choose Trash.")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
        .padding(15)
        .alert("Move this file to Trash?", isPresented: $isShowingTrashConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) { trashFile() }
        } message: {
            Text("\(file.name) will be moved to your Mac's Trash. You can restore it from there.")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .preview(let title, let text):
                PreviewSheet(title: title, text: text)
            case .assistant:
                VerityDocumentAssistantSheet(file: file)
            }
        }
    }

    private var fileIcon: some View {
        let symbol: String
        switch file.url.pathExtension.lowercased() {
        case "pdf": symbol = "doc.richtext.fill"
        case "doc", "docx", "rtf", "odt": symbol = "doc.text.fill"
        case "ppt", "pptx": symbol = "rectangle.stack.fill"
        case "xls", "xlsx", "csv", "tsv": symbol = "tablecells.fill"
        case "png", "jpg", "jpeg", "heic", "gif", "webp": symbol = "photo.fill"
        case "zip", "gz", "tar": symbol = "archivebox.fill"
        case "swift", "py", "js", "ts", "html", "css", "json": symbol = "chevron.left.forwardslash.chevron.right"
        default: symbol = "doc.fill"
        }

        return Image(systemName: symbol)
            .font(.system(size: 25, weight: .medium))
            .foregroundStyle(.orange)
            .frame(width: 48, height: 48)
            .background(Color.yellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
    }

    private func actionButton(_ title: String, subtitle: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDestructive ? .red : .primary)
                    .frame(width: 21)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(isDestructive ? .red : .primary)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    private func saveToVault() {
        do {
            let destination = try VerityFileActions.saveCopyToVault(file.url)
            actionMessage = "Saved a safe copy to Verity Vault as \(destination.lastPathComponent)."
        } catch {
            actionMessage = "I couldn't save that copy: \(error.localizedDescription)"
        }
    }

    private func trashFile() {
        do {
            try VerityFileActions.moveToTrash(file.url)
            VerityModel.shared.setStatus("Goodbye, \(file.name). Into the Trash you go.")
            onClose()
        } catch {
            actionMessage = "I couldn't move it to Trash: \(error.localizedDescription)"
        }
    }

    private func loadPreview() {
        do {
            let text = try FilePreviewReader.preview(for: file.url)
            activeSheet = .preview(title: file.name, text: text)
            actionMessage = "I found something to read."
        } catch {
            actionMessage = error.localizedDescription
        }
    }
}

private enum InspectorSheet: Identifiable {
    case preview(title: String, text: String)
    case assistant

    var id: String {
        switch self {
        case .preview: return "preview"
        case .assistant: return "assistant"
        }
    }
}

private struct PreviewSheet: View {
    let title: String
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VERITY'S BITE-SIZE PREVIEW")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            Text(title)
                .font(.headline)
                .lineLimit(1)
            ScrollView {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(10)
            .background(.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .frame(minWidth: 430, minHeight: 320)
    }
}

enum FilePreviewReader {
    static func preview(for url: URL) throws -> String {
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else { throw PreviewError.cannotRead }
            let pageCount = min(document.pageCount, 12)
            var pieces: [String] = []
            for index in 0..<pageCount {
                if let page = document.page(at: index), let text = page.string, !text.isEmpty {
                    pieces.append("— Page \(index + 1) —\n\(text)")
                }
            }
            let combined = pieces.joined(separator: "\n\n")
            guard !combined.isEmpty else { throw PreviewError.noReadableText }
            return clipped(combined, limit: 18_000, suffix: "\n\n[Preview limited to the first 12 pages or 18,000 characters.]")
        }

        let readableExtensions: Set<String> = ["txt", "md", "markdown", "rtf", "csv", "json", "log", "swift", "py", "js", "ts", "html", "css", "xml", "yaml", "yml", "toml", "sh"]
        guard readableExtensions.contains(url.pathExtension.lowercased()) else { throw PreviewError.unsupported }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard let text = String(data: data.prefix(100_000), encoding: .utf8) else { throw PreviewError.notUTF8 }
        return clipped(text, limit: 18_000, suffix: "\n\n[Preview truncated. The original file was not changed.]")
    }

    private static func clipped(_ text: String, limit: Int, suffix: String) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + suffix
    }
}

enum PreviewError: LocalizedError {
    case cannotRead, noReadableText, unsupported, notUTF8

    var errorDescription: String? {
        switch self {
        case .cannotRead: return "I couldn't open this PDF."
        case .noReadableText: return "This PDF doesn't contain selectable text. It may be a scanned document; ask Verity to read it with a vision-capable model instead."
        case .unsupported: return "Preview isn't available for this file type yet. Try Understand with Verity, or keep a copy."
        case .notUTF8: return "I couldn't decode this text file as UTF-8."
        }
    }
}
