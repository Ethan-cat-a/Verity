# VERITY 1.0.0 — focused product direction

## Product identity

VERITY is one thing: an always-available yellow desktop ball with an enormous ego, instant attitude, useful answers, and an occasional unsettling moment. The design takes the convenience of a classic animated office assistant and pushes the character further without turning the interface into a toolbox.

## Kept

- Desktop ball and one direct conversation surface.
- Text and microphone input.
- Drag-and-drop document understanding.
- Explicit, encrypted local memory with a simple clear/disable control.
- Optional ElevenLabs voice; built-in macOS speech is the fast default.
- Automatic updates and essential settings.
- Rare idle expression changes and occasional restrained uncanny dialogue.

## Removed from the product

- Screen/window capture and the study workflow.
- Command palette and shortcut-driven workflow hub.
- Quiet-presence mode.
- Trash-snack gag and all Trash filename inspection.
- Saved-session management UI and extra quick-action rows.

## Performance focus

- Keep chat context small and stream text as it arrives.
- Answer common identity/greeting prompts locally.
- Use native Mac speech by default to avoid an additional network synthesis round trip.
- Keep remote replies brief unless the user asks for depth.
- Measure first-token and end-to-end latency before claiming further speed gains.

## Guardrails

- The character may boast that it knows everything, but must not invent facts.
- It never pretends to see the screen or monitor the user.
- Unsettling moments remain rare, short, and theatrical rather than threatening.
- Keep document access user-initiated and preserve explicit memory controls.
