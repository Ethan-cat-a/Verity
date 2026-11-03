# VERITY 0.4.1 — your chaotic desktop companion

VERITY is a native macOS desktop companion with the unmistakable yellow Verity sphere: oversized black eyes, an unnervingly wide toothy grin, and a collection of expressive reactions. NOVA V8 powers its intelligence.

## Download VERITY — no Xcode required

**[Download VERITY 0.4.1 for macOS (.dmg)](https://github.com/Ethan-cat-a/Verity/releases/latest/download/VERITY-0.4.1-macOS.dmg)**

1. Download and open the DMG.
2. Drag **VERITY.app** into the **Applications** shortcut.
3. Eject the disk image.
4. Open Terminal and run this one-time command to clear the quarantine flag on this self-built app:
   `xattr -dr com.apple.quarantine /Applications/VERITY.app`
5. Launch VERITY from Applications.

The app bundle is ad-hoc signed and verified during packaging, but it is not signed with an Apple Developer ID certificate and is not notarized. macOS Gatekeeper may therefore block it until you approve this specific build. The command above removes the download quarantine flag only from the installed VERITY app; it does not disable Gatekeeper system-wide. Only run it for a copy you downloaded from this official repository.

[View all VERITY releases](https://github.com/Ethan-cat-a/Verity/releases).

## Verity's expressions

- The original yellow floating sphere look with a huge, slightly unsettling toothy grin.
- Two-frame mouth animation: closed grin ↔ open mouth while speaking or eating.
- Separate shocked, suspicious, angry, sleepy, and manic expressions.
- Automatic face reactions during document drops, voice conversations, jokes, and errors.
- Native macOS app icon generated to match Verity.

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

## NOVA V8 connection

VERITY uses the existing NOVA V8 service:

https://nova-v8.vercel.app/api/chat

The app sends conversation messages to NOVA V8 and keeps provider credentials on the server. No NOVA API key is embedded in VERITY.

## Document privacy

Document text is extracted locally on your Mac. VERITY asks before sending extracted text and your question to NOVA V8. It does not upload the original file as an attachment.

Supported text extraction includes PDF, TXT, Markdown, CSV, TSV, JSON, HTML, XML, common source-code/text formats, and Word/RTF through macOS `textutil`. The extracted text is capped at 48,000 characters and files at 50 MB. Scanned-PDF OCR and spreadsheet extraction are not included yet.

## Build from source

Developers can download the source ZIP, open `VERITY.xcodeproj` in Xcode, select the VERITY scheme and **My Mac**, then press **Command-R**. This developer workflow is optional; normal users install the prebuilt DMG above.

## License and character notice

Application source code is released under the MIT License. The Verity character and its source-series identity are not claimed by this project and remain with their respective rights holders. This is an unofficial fan-made desktop companion and is not affiliated with or endorsed by any rights holder.
