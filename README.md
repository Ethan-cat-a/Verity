# VERITY 0.3.0 — your expressive desktop companion

VERITY is a native macOS desktop companion built around a glossy, expressive yellow ball. It lives on your desktop, accepts files by drag and drop, and uses **NOVA V8** as its intelligence.

## Download VERITY — no Xcode required

The easiest way to install VERITY is the ready-made Mac disk image:

1. Open the **[latest VERITY macOS build](https://github.com/Ethan-cat-a/Verity/actions/workflows/macos-build.yml)**.
2. Select the newest successful run on the `main` branch.
3. Download the **VERITY-macOS** artifact.
4. Open the `VERITY-0.3.0-macOS.dmg` file.
5. Drag **VERITY.app** into the **Applications** shortcut in the disk image.
6. Eject the disk image and launch VERITY from Applications.

You do not need Xcode, Swift, a compiler, or a development environment to use the compiled app. The build is currently unsigned and not notarized, so macOS may show a first-launch security warning. Only open it when you trust the download.

A ZIP containing the same compiled app is included in the artifact as an alternative.

## Talk with Verity

- Press **Talk with Verity** on the floating character.
- Allow microphone and speech recognition access when macOS asks.
- Tap the microphone, speak naturally, then tap it again to finish.
- NOVA V8 creates the reply; ElevenLabs speaks it in Verity's selected Callie voice.

The conversation also supports typed messages. Short greetings, jokes, fun facts, and basic capability questions have local scripted responses; ordinary questions are sent to NOVA V8.

### Configure the Verity voice

1. Open the menu-bar smiley and choose **Settings**.
2. Create an API key in [ElevenLabs API settings](https://elevenlabs.io/app/settings/api-keys).
3. Paste it into the ElevenLabs field in Verity Settings and choose **Save securely**.

The key is stored in macOS Keychain, not in source code, preferences, or GitHub. Until a key is configured, Verity uses the Mac's built-in speech voice.

## What's included in 0.3.0

- Glossy yellow spherical companion with eye highlights, cheek glow, blinking, and animated expressions.
- Floating desktop panel and menu-bar controls.
- Voice and text conversation mode.
- NOVA V8-powered answers with short conversation history.
- ElevenLabs Callie voice using the low-latency Flash speech model.
- Local scripted greetings, jokes, fun facts, and companion reactions.
- Microphone and speech-recognition permission prompts.
- Drag-and-drop file handling and a file inspector.
- Local text preview and document summaries, key points, simple explanations, and document Q&A.
- A Verity Vault that safely copies files without removing the originals.
- Explicit confirmation before extracted document text is sent to NOVA V8.

## NOVA V8 connection

VERITY uses the existing NOVA V8 service:

https://nova-v8.vercel.app/api/chat

The app sends conversation messages to NOVA V8 and keeps provider credentials on the server. No NOVA API key is embedded in VERITY.

## Document privacy

Document text is extracted locally on your Mac. VERITY asks before sending extracted text and your question to NOVA V8. It does not upload the original file as an attachment.

Supported text extraction includes PDF, TXT, Markdown, CSV, TSV, JSON, HTML, XML, common source-code/text formats, and Word/RTF through macOS `textutil`. The extracted text is capped at 48,000 characters and files at 50 MB. Scanned-PDF OCR and spreadsheet extraction are not included yet.

## Voice privacy

The microphone is used only when you activate the talk control. macOS Speech recognition converts your speech into a transcript, which is sent to NOVA V8 for an answer. When an ElevenLabs key is configured, the answer text is sent to ElevenLabs to generate Verity's spoken voice. You can remove the key in Settings at any time.

## Build from source

Developers can download the source ZIP, open `VERITY.xcodeproj` in Xcode, select the VERITY scheme and **My Mac**, then press **Command-R**. This developer workflow is optional; normal users install the prebuilt DMG above.

## License and character notice

Application source code is released under the MIT License. The Verity character and its source-series identity are not claimed by this project and remain with their respective rights holders. This is an unofficial fan-made desktop companion and is not affiliated with or endorsed by any rights holder.
