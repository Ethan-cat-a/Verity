# VERITY 0.9.0 — implementation roadmap

## Delivered in this implementation pass

- **Study actions on reviewed screen text:** Screen → quiz, Make a study set, Socratic guidance, Practice test, and Explain focus.
- **Review-first workflow:** the user selects a window, captures once, edits or redacts OCR text, and confirms before content is sent.
- **Blind Mode:** clears the active screen capture and blocks window listing, capture, and sending until re-enabled.
- **Per-app screen filters:** optional allow-list plus the existing deny-list; the deny-list and built-in sensitive-app exclusions always win.
- **Command palette:** keyboard-accessible actions for chat, study/window understanding, memory/sessions, and Settings.
- **Quiet Presence:** shrinks the character without monitoring the user's activity.
- **Calmer default personality and speech:** removes exaggerated emotional tags and changes the default to the smoother existing library voice.

## Still planned

### Study system
- Persist flashcard decks locally and add spaced-repetition scheduling.
- Add an interactive flashcard review screen and image-occlusion cards.
- Build an interactive timed practice-test interface with answer submission and concept-level scoring.
- Add real study-session snapshots and resume points beyond ordinary chat snapshots.
- Add optional educational video recommendations for user-selected text.

### Presence and interaction
- Add an app-wide global hotkey that works while VERITY is not focused; the current Command-K shortcut is available while the companion window is active.
- Add subtle attention pulses for user-approved notifications.
- Add more precise multi-monitor window selection and context switching.
- Add non-destructive annotation overlays only after a separate permission and privacy review.

### Trust and privacy
- Add a local activity ledger showing which app/window was explicitly captured and which actions were taken, without retaining OCR content by default.
- Add bulk deletion for that metadata ledger.
- Keep Blind Mode and per-app allow/deny filters as hard gates for screen capture.

### Voice and performance
- Generate an original, calm US-English companion voice after the user supplies the exact preview sentence.
- Continue cancellable phrase synthesis and evaluate actual end-to-end speech latency.
- Measure first-token and full-response timing locally without storing user text or document content.
- Profile the NOVA V8 route before changing model routing.

### Deferred integrations
- Calendar/PowerSchool reminders, music recognition and transport controls, passive distraction detection, and background screen monitoring are intentionally excluded from this release direction.

## Release checks

- Build and regression tests must pass in GitHub Actions.
- Test Blind Mode, app allow/deny filters, study prompts, command shortcuts, voice migration, and updater compatibility.
- Validate the installed app and automatic update flow on a real macOS installation before publishing a stable release.
- Preserve existing document handling, encrypted memory, saved conversations, microphone permissions, and the automatic updater.
