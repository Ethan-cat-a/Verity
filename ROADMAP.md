# VERITY 0.9.0 — next update plan

## Goal

Make VERITY feel like a useful Clippy-style desktop assistant rather than a decorative desktop pet. Keep the fixed lower-right helper from 0.8.0, but make its help more contextual, its speech more immediate, and its character more faithful to the approved reference.

## Planned work

### 1. Contextual quick-help bubble
- Expand the hover bubble into a compact helper card with relevant actions such as "Explain this", "Summarize a document", and "Help me write".
- Offer suggestions only when the user opens VERITY, drops a document, or explicitly shares a window. No background screen scanning.
- Keep the full conversation window one click away and preserve the existing document, memory, and Trust Center workflows.

### 2. Real-time voice
- Stream generated speech in cancellable chunks so VERITY can begin speaking before the entire answer has been synthesized.
- Keep text and audio synchronized, support interruption, and animate the mouth to the actual speech state.
- Continue using an original licensed/library voice with broad character traits. Do not clone or imitate a real voice actor.

### 3. Intelligence speed and reliability
- Measure time-to-first-token and total response time in the app, with no message content or private document text in telemetry.
- Profile the NOVA V8 chat route and reduce upstream latency where it is actually occurring.
- Evaluate a faster default model route with a quality fallback, rather than guessing at a model change from the client.
- Preserve streaming, relevant memory, and accurate document analysis.

### 4. Character reference pass
- Refine the face, proportions, mouth, and expressions against an approved visual reference for VERITY.
- Keep the deliberately severe, uncanny direction; avoid glossy, soft, cute, or childlike styling.
- Add restrained contextual expressions without random desktop movement.

### 5. Release quality
- Add regression checks for fixed positioning, idle-expression preference, voice cancellation, streamed text, and updater compatibility.
- Test the complete update flow on a real macOS installation before publishing.
- Preserve existing memory, document, screen-understanding, privacy, and automatic-update features.

## Acceptance criteria

- The helper remains fixed in the lower-right corner and opens with one click.
- Quick-help suggestions are contextual and user-initiated; no passive screen monitoring is introduced.
- Speech starts while the answer is still streaming and stops promptly when interrupted.
- First-token and total response latency are measured before choosing a backend/model optimization.
- The new face direction is compared against an approved reference before it is called final.
- The macOS build, regression tests, release packaging, and update installation checks pass.
