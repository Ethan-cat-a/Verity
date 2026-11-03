# VERITY 0.8.1 — desktop helper

VERITY is a native macOS desktop assistant built around a bright yellow smiley-sphere character: glossy shading, simple black oval eyes, and a curved smile. Its normal personality is cheerful and helpful; the horror expression is a separate, brief, occasional idle event.

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

## Character and desktop helper

- Verity is docked in the lower-right corner of the main display. It does not roam, roll, or move around freely.
- Click the character once to open the full assistant and document window. Hovering displays a compact "NEED A HAND?" prompt; right-click opens helper options.
- The normal character returns to the bright yellow, glossy smiley-sphere design, with two plain black oval eyes and a simple curved smile.
- The large toothy grin, uneven stare, and raised brows are reserved for a brief horror expression.
- While otherwise idle, the horror expression may happen at random intervals (roughly every 52–138 seconds) and lasts about 2.4–3.6 seconds before Verity returns to his normal face.
- Disable **Occasional unsettling idle stare** in Settings to turn this off.
- Speaking, eating, suspicious, angry, shocked, and eerie expressions remain separate states.
- When enabled, Verity may still sample a random filename from the user's Trash for its visual snack reaction. **Trash snacks are visual only:** it never opens, deletes, moves, renames, or restores the item. Disable "Let Verity snack from Trash" in Settings to turn this off.

## Talk with Verity

- Click Verity, then choose **Talk with Verity** in the assistant window.
- Allow microphone and speech recognition access when macOS asks.
- Tap the microphone, speak naturally, then tap it again to finish.
- Verity responds through its connected intelligence service and speaks in its selected character voice.

The conversation also supports typed messages. Short greetings, jokes, fun facts, and basic capability questions have local scripted responses. Replies stream partial text as the connected service returns it. The app uses a smaller recent-message window to reduce prompt overhead. Spoken output is synthesized in short phrases, with the next phrase prepared while the current one plays; playback can be interrupted.

### Configure the Verity voice

1. Open the menu-bar smiley and choose **Settings**.
2. Create an API key in [ElevenLabs API settings](https://elevenlabs.io/app/settings/api-keys).
3. Paste it into the ElevenLabs field in Verity Settings and choose **Save securely**.

The key is stored in macOS Keychain, not in source code, preferences, or GitHub. The default is an expressive young-adult male library voice selected for lively, character-led delivery. Speech uses Eleven v4 and is prepared phrase by phrase so the first part can play while the next phrase is being generated. The voice is an original library voice, not an imitation or clone of Verity's credited performer. Without a key, VERITY selects the best available enhanced English male system voice on the Mac.

### Quick helper actions

The conversation includes shortcuts for **Explain simply**, **Help me write**, **Summarize**, and **Tell me a joke**. These start user-requested tasks; they do not monitor the desktop.

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

## Next update

The planned VERITY 0.9.0 work is tracked in [ROADMAP.md](ROADMAP.md).

## Build from source

Developers can download the source ZIP, open `VERITY.xcodeproj` in Xcode, select the VERITY scheme and **My Mac**, then press **Command-R**. This developer workflow is optional; normal users install the prebuilt DMG above.

## License and character notice

Application source code is released under the MIT License. The Verity character and its source-series identity are not claimed by this project and remain with their respective rights holders. This is an unofficial fan-made desktop companion and is not affiliated with or endorsed by any rights holder.
