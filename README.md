# VERITY 0.2.0 — macOS desktop companion

VERITY is a native macOS desktop companion built around a bright yellow spherical smiley character. It lives on your desktop, accepts files by drag and drop, and uses **NOVA V8** as its AI brain.

## Download VERITY

**[Download the latest source package (.zip)](https://github.com/Ethan-cat-a/Verity/archive/refs/heads/main.zip)**

To download a ready-built Mac app, open the **[VERITY macOS build workflow](https://github.com/Ethan-cat-a/Verity/actions/workflows/macos-build.yml)**, select the latest successful run, then download its **VERITY-macOS** artifact from the Artifacts section. The build is an unsigned development build.

## Install from the source ZIP

1. Download the source ZIP using the link above.
2. Double-click the ZIP to extract it.
3. Open the extracted **VERITY** folder.
4. Double-click **VERITY.xcodeproj** to open it in Xcode.
5. In Xcode, choose the **VERITY** scheme and **My Mac** as the run destination.
6. Press **Command-R** to build and launch VERITY.
7. The floating yellow character appears on your desktop. You can also open it from the smiley icon in the menu bar.

Requires macOS 13 or later and Xcode 15 or later. There are no third-party Swift package dependencies.

## Install the prebuilt app artifact

1. Open the [macOS build workflow](https://github.com/Ethan-cat-a/Verity/actions/workflows/macos-build.yml).
2. Select the newest run marked **Success**.
3. Download the **VERITY-macOS** artifact ZIP near the bottom of the run page.
4. Double-click the downloaded ZIP to extract **VERITY.app**.
5. Drag **VERITY.app** into your Applications folder and launch it.

This is an unsigned development build, not a notarized public release. macOS may ask you to confirm that you want to open an app downloaded from the internet. Only continue when you trust the source.

## What's included in 0.2.0

- Floating yellow smiley character with an idle animation.
- Drag-and-drop file handling and a file inspector.
- Local text preview for supported formats.
- Document summaries, key-point extraction, simple explanations, and custom document questions.
- Local file text extraction followed by NOVA V8 analysis.
- A Verity Vault that safely copies files without removing the originals.
- Explicit confirmation before extracted document text is sent to NOVA V8.

## NOVA V8 connection

VERITY is wired to the existing NOVA V8 service:

https://nova-v8.vercel.app/api/chat

The app uses the same **messages** request contract as NOVA Copilot. It checks the service's health endpoint on launch and sends document questions through the NOVA V8 chat API. No NOVA API key is embedded in the app; provider credentials remain on the server.

To check the connection, open the menu-bar smiley → **Settings** → **Test connection**. When the status says **NOVA V8 connected**, Verity's document assistant is ready.

## Document privacy and supported formats

VERITY extracts text on your Mac before it contacts NOVA V8. Dropping a file does not send it anywhere. The app asks for confirmation before sending the extracted text and your question to the NOVA V8 service. The original file itself is not uploaded as an attachment.

Current text extraction supports PDF, TXT, Markdown, CSV, TSV, JSON, HTML, XML, common source-code/text formats, and Word/RTF files through macOS **textutil**. The extracted text is capped at 48,000 characters and files are limited to 50 MB. Scanned-PDF OCR and spreadsheet extraction are not included yet.

VERITY does not permanently delete files. Keeping a copy places it in **Documents/Verity Vault**. Moving an item to Trash requires an explicit confirmation.

## Build from source

Clone the repository, open **VERITY.xcodeproj** in Xcode, select the VERITY scheme and **My Mac**, then press **Command-R**.

## License and character notice

Application source code is released under the MIT License. The Verity character and its source-series identity are not claimed by this project and remain with their respective rights holders. This is an unofficial fan-made desktop companion and is not affiliated with or endorsed by any rights holder.
