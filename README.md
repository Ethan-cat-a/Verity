# VERITY 1.3.0 — the know-it-all orb

**Meet the smartest thing on your desktop. It knows it.**

A little Clippy energy. A much bigger ego. A slightly unsettling smile.

VERITY is a tiny yellow desktop companion with a softly lit 3D orb, an original smile, and an air of complete certainty. Click it, ask a question, and it gets straight to the answer. It is quick, smug, funny, useful, and occasionally a little too still.

Version 1.3.0 adds optional folder awareness for supported documents while keeping indexing on-device and sharing only question-matched excerpts. Version 1.2.3 added safer update rollback and locally searched file references. Version 1.2.2 asks before installing updates and lets you choose files to share with VERITY in conversation. Version 1.2.1 refined the orb's lighting and animations; 1.2.0 introduced the animated orb, original scripted character replies, and an optional Fish Audio community voice.

## Download

**[Download VERITY for macOS](https://github.com/Ethan-cat-a/Verity/releases/latest)**

1. Download and open the DMG.
2. Drag **VERITY.app** into **Applications**.
3. Eject the disk image and launch VERITY.

This self-built app is ad-hoc signed, not Developer ID signed or notarized. If macOS blocks a copy downloaded from this official repository, install it into Applications, then run this one-time command in Terminal:

```sh
xattr -dr com.apple.quarantine /Applications/VERITY.app
```

This clears the quarantine flag only for the installed VERITY app; it does not disable Gatekeeper system-wide.

## The whole idea

- A softly lit yellow 3D smiley orb stays docked on your desktop, with animated expressions and an occasional unsettling stare.
- Click it to open one simple conversation. Type or use the microphone.
- Drop a supported document into the window and ask about it.
- Use the conversation paperclip to approve up to five files for chat. VERITY reads only those files locally, searches their extracted text for passages related to each question, and sends up to 8,000 relevant characters total to NOVA. Answers cite passages with markers you can inspect in the file preview. Preview, refresh, or remove each approved file in the chat; file text stays in memory until you remove it or quit the app.
- Optionally enable **Settings → File awareness** and choose a folder, including your home folder. VERITY locally indexes supported PDFs, Word documents, text, and code under it. Hidden folders, Library, and app packages are skipped; the index is capped at 2,000 documents or 12 million characters. Only question-matched excerpts (up to 8,000 characters) are sent to NOVA. Turning the option off removes the saved folder permission and index; earlier replies in an open chat remain.
- Document answers cite clickable PDF pages or text sections; open a citation to inspect the passage Verity used.
- VERITY has a huge ego, a sharp tongue, and a habit of acting like the answer was obvious.
- Original scripted replies handle common greetings and character questions without a network request.
- Say **“Remember that…”** to save a note. Memory is explicit, encrypted on your Mac, and can be disabled or cleared in Settings.

## Fast by default

- Replies stream into the conversation as they arrive.
- Only the four latest chat turns are sent, with a per-message context cap, to avoid hauling the whole conversation into every request.
- Common greetings and character questions are answered locally.
- The built-in macOS voice is the fast default. Fish Audio and ElevenLabs are optional online voice providers in Settings; only one can be enabled at a time.
- Add a Fish Audio API key in Settings to enable the community-published VERITY voice. The Fish model is community-made, not an official recording.
- Voice API keys are stored in macOS Keychain. When an online voice is enabled, VERITY sends reply text to the selected provider for speech synthesis.
- When ElevenLabs is enabled, VERITY prepares the next speech segment while the current one plays.

The speed of a full AI answer still depends on the network and the NOVA service. VERITY cannot make a remote model respond faster than the service itself.

## Privacy

Screen awareness is off by default. When you explicitly enable it, VERITY checks only the frontmost app window about every six seconds. It uses on-device text recognition and simple keyword rules; screenshots are neither uploaded nor saved. Obvious adult keywords in visible text on supported browsers can trigger a brief blur and, when enabled, a Command-W tab close. The separate school-hours gaming guard is also opt-in. This is a best-effort text check, not reliable image moderation: it can miss image-only content or misread context. Closing a tab may discard unsaved form contents. VERITY receives what you type, say while the microphone is active, or deliberately provide by choosing files or dropping a document. Document text is extracted locally and sent to NOVA when you ask for an answer. Paperclip files and the optional approved folder are searched locally; only relevant excerpts, up to 8,000 characters total, are sent with each AI question. Folder indexing is in memory and can be removed in Settings; earlier replies may remain in chat history. If you enable Fish Audio or ElevenLabs, the reply text is also sent to that selected provider for speech synthesis. Voice API keys are stored in macOS Keychain. Saved memories are created only on an explicit “remember” request.

## School-hours gaming guard

When explicitly enabled in Settings, VERITY checks for supported game activity on weekdays from **08:00 to 15:30**, using the Mac's local time. It recognizes CrazyGames, Poki and Roblox in supported browser windows, and foreground Roblox, Steam and selected game apps. It shows a special scolding reaction, blurs the display, then closes the matching browser tab with Command-W or normally quits the game app with Command-Q. It re-checks the exact app/window and game signal immediately before closing; switching to a different page or app leaves the new window alone. This is a best-effort local check, not universal game detection. A normal app quit can interrupt a game session, so save progress first.

## Diagnostics

Settings opens in its own window from the menu-bar menu. The Screen awareness section includes **Check active window now** and shows the result of the latest scan, including missing permissions or an unavailable screenshot. Native game apps are checked by foreground app identity before OCR; browser pages still depend on their visible title/text and Screen Recording permission.

## Automatic updates

VERITY checks GitHub Releases when a check is due at launch, then every six hours. When an update is available, it asks whether to install it. If approved, VERITY verifies the release archive's SHA-256 digest and app signature, then keeps a rollback copy until the new app launches successfully. You can turn automatic checks on or off or check manually in **Settings → Updates**. Installation requires `VERITY.app` to be directly inside a writable `Applications` folder.

## Essential controls

The menu bar contains **Ask Verity**, show/hide desktop ball, Settings, update checking, and Quit. Settings include optional folder search, screen awareness, the blur/close behavior, and the weekday school-hours gaming guard, alongside the occasional unsettling stare, voice choice, explicit memory, connection status, and updates.

## Build from source

Open `VERITY.xcodeproj` in Xcode, choose the VERITY scheme and **My Mac**, then press **Command-R**.

To publish a release, update `VERSION` and the matching Xcode version, then push a matching `vX.Y.Z` tag. GitHub Actions validates the tag and version before publishing. Existing release assets are never replaced; publish a new version for new installers.
