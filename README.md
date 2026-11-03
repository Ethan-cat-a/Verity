# VERITY 0.7.0 — your chaotic desktop companion

VERITY is a native macOS desktop companion with the unmistakable yellow Verity sphere: oversized black eyes, a simple curved smile at rest, and an exaggerated toothy grin when it gets animated or excited. Verity has its own distinct character and personality.

## Download VERITY — no Xcode required

**[Download the latest stable VERITY for macOS](https://github.com/Ethan-cat-a/Verity/releases/latest)**

Download the latest stable build from the official GitHub Releases page above.

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
- A clean, tooth-free curved smile at rest; the toothy grin appears when Verity opens its mouth to speak, eat, or react.
- Separate shocked, suspicious, angry, sleepy, and manic expressions.
- Automatic face reactions during document drops, voice conversations, jokes, and errors.
- Native macOS app icon generated to match Verity.

## Chaotic desktop pet

- Verity now appears as a transparent, borderless desktop ball rather than living inside the large card window.
- It wanders naturally within the current display, following short curved paths with eased starts and stops. It no longer jumps to a random monitor.
- Dragging gives the ball a small, damped roll with momentum; rotation follows the distance travelled.
- Drag the ball itself to roll it around. It says a randomly selected grumpy line when you release it.
- Double-click the ball to open the full conversation and document window. Right-click for desktop-pet options.
- Idle animation uses a subtle breath, occasional natural blink, and a simple curved smile. Eating and talking keep the separate two-frame toothy jaw animation.
- When hungry, Verity may sample a random item name from your user Trash for a chomping gag.
- **Trash snacks are visual only.** It reads only the filename and never opens, deletes, moves, renames, or restores the item. Disable "Let Verity snack from Trash" in Settings to turn this off.

## Talk with Verity

- Press **Talk with Verity** on the floating character.
- Allow microphone and speech recognition access when macOS asks.
- Tap the microphone, speak naturally, then tap it again to finish.
- Verity responds through its connected intelligence service and speaks in its selected character voice.

The conversation also supports typed messages. Short greetings, jokes, fun facts, and basic capability questions have local scripted responses. Replies display partial text whenever the connected service supports streaming. Verity can also start speaking without locking the chat input.

### Configure the Verity voice

1. Open the menu-bar smiley and choose **Settings**.
2. Create an API key in [ElevenLabs API settings](https://elevenlabs.io/app/settings/api-keys).
3. Paste it into the ElevenLabs field in Verity Settings and choose **Save securely**.

The key is stored in macOS Keychain, not in source code, preferences, or GitHub. Choose between three original character-style presets and adjust speaking pace in Settings. The default is a bright, high-energy cartoon voice; it is an existing library preset, not a copy of the credited performer. Without a key, Verity uses the Mac voice with a slightly higher pitch and livelier pace.

## Memory & context (0.6.0)

Verity remembers only information you explicitly ask it to save. In chat, start a message with **“Remember that…”** to save a note. Use **Memory & sessions** to search, edit, pin, or delete saved entries, or to clear all memories.

Memories are stored as an encrypted local archive in the user's Application Support directory. The archive uses AES-256-GCM, with its encryption key stored in macOS Keychain. Existing plaintext memory archives from 0.6.0 are migrated automatically on first launch. When memory use is enabled, Verity selects a small number of relevant saved entries for a conversation; it does not send the entire memory archive. You can turn memory use off in the Memory Manager at any time. Passwords, access codes, API keys, and payment details are blocked from new memory entries.

Use **Save session** in chat to snapshot the last part of a conversation. Resume or delete saved sessions from the Sessions tab. A snapshot contains the selected chat messages and a simple goal/next-step note; it does not restore other applications or unsaved files.

## Trust Center and screen understanding (0.5.0)

Screen understanding is off by default. When enabled, the user chooses a visible window and manually captures one frame. VERITY reads text locally with Apple's Vision framework, shows the screenshot and OCR text for review, and allows the user to edit or redact that text. Only the reviewed text and the user's question are sent to Verity's connected intelligence service after a separate confirmation. The screenshot itself is not uploaded. Password and keychain apps are excluded from the window list by default; additional app names can be added in Settings.

## Automatic updates

VERITY checks the official GitHub Releases endpoint at launch and every six hours. Automatic download and installation are enabled by default and can be disabled independently from update checks in Settings. Before replacing the app, VERITY downloads the version-matched ZIP, verifies the SHA-256 digest published by GitHub, checks the app bundle identifier and version, and verifies its code signature. A separate helper waits for VERITY to quit, replaces the app bundle, and launches the updated version. Automatic replacement is supported when `VERITY.app` is directly inside a writable `/Applications` or `~/Applications` folder; otherwise Settings provides the manual DMG installer. The current installer remains ad-hoc signed and is not notarized, so macOS may still require the one-time quarantine approval described above.

## Document privacy

Document text is extracted locally on your Mac. VERITY asks before sending extracted text and your question to Verity's connected intelligence service. It does not upload the original file as an attachment.

Supported text extraction includes PDF, TXT, Markdown, CSV, TSV, JSON, HTML, XML, common source-code/text formats, and Word/RTF through macOS `textutil`. The extracted text is capped at 48,000 characters and files at 50 MB. Scanned-PDF OCR and spreadsheet extraction are not included yet.

## Build from source

Developers can download the source ZIP, open `VERITY.xcodeproj` in Xcode, select the VERITY scheme and **My Mac**, then press **Command-R**. This developer workflow is optional; normal users install the prebuilt DMG above.

## License and character notice

Application source code is released under the MIT License. The Verity character and its source-series identity are not claimed by this project and remain with their respective rights holders. This is an unofficial fan-made desktop companion and is not affiliated with or endorsed by any rights holder.
