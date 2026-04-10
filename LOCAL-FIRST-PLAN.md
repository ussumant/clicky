# Clicky Local-First: Build Sessions Plan

Goal: Replace all cloud dependencies so Clicky runs 100% locally.

## Current State

| Layer | Cloud (Current) | Local Replacement | Status |
|-------|----------------|-------------------|--------|
| Chat (Claude) | Anthropic API via CF Worker | Claude CLI adapter | **DONE** |
| Transcript cleanup | None | Muesli FillerWordFilter + ArtifactsFilter | **DONE** |
| ASR (Speech-to-Text) | AssemblyAI streaming WS | Apple Speech on-device (runtime toggle) | **DONE** |
| TTS (Text-to-Speech) | ElevenLabs via CF Worker | macOS AVSpeechSynthesizer | **DONE** |
| Agent CLI | None | `clicky-cli` JSON interface | **DONE** |
| Type Mode | None | Muesli PasteController (speak → paste at cursor) | **DONE** |

## Build Sessions

### Session 1: Local TTS (macOS AVSpeechSynthesizer) ~1-2 hours
**Why first:** Simplest cloud replacement. AVSpeechSynthesizer is built into macOS, no models to bundle.

**What to build:**
- `LocalTTSClient.swift` — wraps `AVSpeechSynthesizer` with the same interface as `ElevenLabsTTSClient`
- Match API: `speak(text:)`, `stopPlayback()`, `isPlaying` property
- Voice selection: use a high-quality Siri voice (e.g., "com.apple.voice.premium.en-US.Zoe")
- Add "TTS" picker to panel UI: "Cloud" (ElevenLabs) / "Local" (macOS)
- Wire into CompanionManager alongside existing ElevenLabs client

**Reference:** `ElevenLabsTTSClient.swift` (~81 lines) for the interface to match.

**Verification:** Push-to-talk → response → hear macOS voice instead of ElevenLabs.

---

### Session 2: Local ASR (Parakeet TDT on ANE) ~4-6 hours
**Why:** This is the big one. Replaces AssemblyAI cloud streaming with on-device inference.

**What to build:**
- Port `StreamingDictationController` pattern from Muesli (the streaming ASR pipeline)
- Port `NemotronStreamingTranscriber` (CoreML model execution on ANE)
- Bundle Parakeet TDT CoreML model in the app
- Create `LocalTranscriptionProvider.swift` conforming to `BuddyTranscriptionProvider` protocol
- Wire as a new provider option alongside AssemblyAI/OpenAI/Apple Speech

**Key architecture from Muesli:**
- 8960-sample chunks (560ms at 16kHz) for CTC streaming
- ANE pre-warm via silence chunk on startup
- Serial chunk drain with lock for stateful decoder
- Start mic before model is ready (buffer early audio)

**Reference files:**
- `Muesli/StreamingDictationController.swift` — streaming pipeline
- `Muesli/StreamingMicRecorder.swift` — AVAudioEngine buffer capture
- `Clicky/BuddyTranscriptionProvider.swift` — protocol to implement
- `Clicky/AssemblyAIStreamingTranscriptionProvider.swift` — existing provider pattern

**Verification:** Push-to-talk with airplane mode on → transcript appears → response works.

---

### Session 3: Type Mode (PasteController) ~2-3 hours
**Why:** New capability. Speak → text appears at cursor position (no Claude, no voice response).

**What to build:**
- Port `PasteController.swift` from Muesli (clipboard save/restore + Cmd+V simulation)
- Add "Mode" picker to panel: "Voice" (current) / "Type" (new)
- In Type mode: push-to-talk → transcribe → filter → paste at cursor
- Skip Claude + TTS entirely in this mode
- Optional: show transcript briefly in overlay before pasting

**Reference:** Muesli `PasteController.swift` — clipboard management + CGEvent paste.

**Verification:** Open any text editor → push-to-talk → spoken words appear at cursor.

---

### Session 4: Agent CLI (`clicky-cli`) ~2-3 hours
**Why:** Let coding agents interact with Clicky programmatically.

**What to build:**
- New SwiftPM executable target: `clicky-cli`
- JSON-first output (follow Muesli's envelope pattern)
- Commands:
  - `clicky-cli spec` — command tree
  - `clicky-cli history list` — recent conversations
  - `clicky-cli history get <id>` — full conversation
  - `clicky-cli config get` — current settings (model, backend, mode)
  - `clicky-cli config set <key> <value>` — change settings
- Share storage with main app via App Group or known path

**Reference:** Muesli `MuesliCLI/main.swift` — full JSON CLI pattern.

**Verification:** `clicky-cli history list` returns recent conversations as JSON.

---

## Execution Order

```
Session 1 (TTS)  →  Session 2 (ASR)  →  Session 3 (Type Mode)  →  Session 4 (CLI)
   ~2hr              ~5hr                 ~3hr                      ~2hr
```

After Sessions 1+2: Clicky works fully offline (airplane mode test).
After Session 3: New dictation capability.
After Session 4: Agent-programmable.

## What Still Needs the Cloud Worker

Even after all sessions, the CF Worker stays for:
- Users who prefer ElevenLabs voice quality (Cloud TTS toggle)
- Users who prefer AssemblyAI accuracy (Cloud ASR toggle)
- The API backend option (for users with API keys, no CLI)

All cloud services become opt-in rather than required.
