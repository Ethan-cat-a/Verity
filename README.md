# VERITY 0.2.0 — macOS desktop companion

VERITY is a native macOS menu-bar companion built around a bright yellow spherical smiley-face helper. This repository contains an unofficial fan-made desktop project; it is not affiliated with or endorsed by any rights holder. The character artwork is a hand-drawn SwiftUI interpretation.

## Open in Xcode

1. Clone or download this repository.
2. Open `VERITY.xcodeproj` in Xcode.
3. Select the **VERITY** scheme and **My Mac** as the run destination.
4. Press Command-R. VERITY appears near the top-right of the desktop, with a smiley control in the menu bar.

The project targets macOS 13.0 or later and has no external package dependencies.

## Included in 0.2.0

- Floating yellow spherical Verity character with idle animation and drag-and-drop file interaction.
- File preview and safe-copy actions, with originals kept unless the user explicitly chooses Trash.
- Document assistant actions: summarize, extract key points, explain simply, and ask custom questions.
- OpenAI Responses API integration for supported document files.
- API key stored in macOS Keychain.
- Explicit confirmation before a document is sent to OpenAI; dropping a file alone does not upload it.

## Configure document understanding

1. Run VERITY in Xcode.
2. Open the menu-bar control and choose Settings.
3. Add an OpenAI API key. VERITY stores it in macOS Keychain.
4. Choose a supported model in Settings.
5. Drop a supported document onto Verity, choose Understand with Verity, then select an action or ask a question.
6. Confirm the upload before the file is transmitted to the OpenAI Responses API.

API usage is billed separately by OpenAI and is not included with a ChatGPT subscription. Manage API keys at https://platform.openai.com/api-keys.

## Supported document inputs

PDF, DOC, DOCX, RTF, ODT, PPT, PPTX, XLS, XLSX, CSV, TSV, TXT, Markdown, JSON, HTML, XML, and selected source-code formats. Files must be smaller than 50 MB per request. PDF input can include page images as well as extracted text. Non-PDF office documents are parsed as text by the API; embedded images and charts may not be interpreted.

## File safety and privacy

- VERITY does not permanently delete files.
- Keep a copy in Verity Vault copies the original into the user's Documents folder.
- Move to Trash requires confirmation.
- Document analysis requires explicit confirmation before transmitting the selected document to OpenAI.
- The API key is stored in Keychain, not source code or UserDefaults.
- Responses requests set store to false; the app does not persist document contents or AI responses to disk.

## Current limitations

This is an early development build. Voice, OCR for scanned images, autonomous Mac actions, folder automation, and a full conversational desktop agent are not included yet. Users must provide their own OpenAI API key. This is an unsigned local development prototype and has not been compiled in this Linux environment because Xcode and the macOS SDK are unavailable here. App Sandbox is disabled in this prototype; review sandbox entitlements, signing, and notarization before distribution.

## License and character notice

Application source code is released under the MIT License. The Verity character and source-series identity are not claimed by this project and remain with their respective rights holders. This is an unofficial fan-made desktop companion.
