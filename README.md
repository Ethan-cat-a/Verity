# VERITY 1.0.0 — the know-it-all ball

**Meet the smartest thing on your desktop. It knows it.**

A little Clippy energy. A much bigger ego. A slightly unsettling smile.

VERITY is a tiny yellow desktop companion that acts like it knows everything. Click the ball, ask a question, and it gets straight to the answer. It is quick, smug, funny, useful, and occasionally a little too still.

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

- A bright yellow smiley ball stays docked on your desktop.
- Click it to open one simple conversation. Type or use the microphone.
- Drop a supported document into the window and ask about it.
- VERITY has a huge ego, a sharp tongue, and a habit of acting like the answer was obvious.
- Every few minutes, when it is idle, the smile can briefly become unsettling. It then returns to normal.
- Say **“Remember that…”** to save a note. Memory is explicit, encrypted on your Mac, and can be disabled or cleared in Settings.

## Fast by default

- Replies stream into the conversation as they arrive.
- Only the four latest chat turns are sent, with a per-message context cap, to avoid hauling the whole conversation into every request.
- Common greetings and character questions are answered locally.
- The built-in macOS voice is the default because it avoids an extra voice-synthesis request. ElevenLabs is optional in Settings.
- When ElevenLabs is enabled, VERITY prepares the next speech segment while the current one plays.

The speed of a full AI answer still depends on the network and the NOVA service. VERITY cannot make a remote model respond faster than the service itself.

## Privacy

VERITY does not watch your screen, capture windows in the background, inspect the Trash, or monitor app activity. It only receives what you type, say while the microphone is active, or deliberately provide by dropping a document. Document text is extracted locally and sent for analysis only when you ask for an answer. Saved memories are created only on an explicit “remember” request.

## Essential controls

The menu bar contains **Ask Verity**, show/hide desktop ball, Settings, update checking, and Quit. Settings are limited to the occasional unsettling stare, voice choice, explicit memory, connection status, and updates.

## Build from source

Open `VERITY.xcodeproj` in Xcode, choose the VERITY scheme and **My Mac**, then press **Command-R**.
