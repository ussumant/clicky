# AGENTS.md - leanring-buddy (Main App Target)

This target is the menu bar-only macOS app. The authoritative architecture lives in the root `AGENTS.md`; this file calls out app-target specifics.

## Current App Structure

- `leanring_buddyApp.swift` creates `CompanionManager`, starts the menu bar panel, and keeps the app dockless via `LSUIElement`.
- `CompanionManager.swift` owns permissions, push-to-talk, screen capture, AI backends, TTS, overlay state, and the new `PawscriptExecutionManager`.
- `CompanionPanelView.swift` hosts the compact menu bar UI and embeds `PawscriptPanelView` after permissions are granted.
- `OverlayWindow.swift` owns the click-through multi-monitor overlay, flight animation, speech bubbles, waveform/spinner states, and Spanks rendering.
- `Pawscript*.swift` files implement tutorial-source extraction, WR-compatible skill storage, live screen matching, Browser Use execution, and step progress.
- `PawscriptSkills/*.json` contains bundled demo/fallback skill packages.

## Pawscript Rules

- Pawscript's primary agent path is Browser Use in a visible browser; Codex prompt execution is not the main demo path.
- Do not auto-install demo tools from the app. Surface missing `yt-dlp`, Browser Use, or Python setup as clear setup errors.
- Keep Pawscript code in focused files; avoid adding more large feature logic to `CompanionManager.swift`, `CompanionPanelView.swift`, or `OverlayWindow.swift`.
- Preserve existing Clicky voice, permission, TTS, subtitle, and overlay behavior while adding Pawscript paths.
