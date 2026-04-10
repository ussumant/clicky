---
topic: voice-and-transcription
last_compiled: 2026-04-10
sources: 7
status: active
---

# Voice and Transcription

## Purpose [coverage: high — 7 sources]

The voice and transcription topic covers the entire push-to-talk pipeline: from detecting the keyboard shortcut, capturing microphone audio, converting it to the right format, streaming it to a transcription provider, and delivering the finalized transcript to the companion engine. This is the input half of Clicky's voice interaction loop.

The system is designed around a pluggable provider architecture — AssemblyAI (real-time streaming), OpenAI (upload-based), and Apple Speech (local fallback) — with the active provider selected at launch via `Info.plist` configuration.

## Architecture [coverage: high — 7 sources]

**Shortcut detection layer:**
- `GlobalPushToTalkShortcutMonitor.swift` — owns a listen-only `CGEvent` tap at `cgSessionEventTap`. Monitors `flagsChanged`, `keyDown`, `keyUp` events. Publishes `.pressed` / `.released` transitions via Combine `PassthroughSubject`.
- `BuddyPushToTalkShortcut` (enum in BuddyDictationManager.swift) — defines the shortcut options (ctrl+option is default) and the state machine for detecting press/release transitions from raw CGEvent data. Supports modifier-only shortcuts and modifier+space variants.

**Audio capture and dictation:**
- `BuddyDictationManager.swift` (~866 lines) — the core dictation manager. Captures audio via `AVAudioEngine`, routes PCM buffers to the active transcription provider, manages permission prompts, tracks audio power levels for the waveform UI, and delivers finalized transcripts via callbacks.
- Key state: `isRecordingFromMicrophoneButton`, `isRecordingFromKeyboardShortcut`, `isFinalizingTranscript`, `isPreparingToRecord`, `currentAudioPowerLevel`, `recordedAudioPowerHistory`

**Provider protocol:**
- `BuddyTranscriptionProvider` protocol — `startStreamingSession(keyterms:...)` returns a `BuddyStreamingTranscriptionSession` which accepts audio buffers and delivers transcript updates.
- `BuddyStreamingTranscriptionSession` protocol — `appendAudioBuffer()`, `requestFinalTranscript()`, `cancel()`, `finalTranscriptFallbackDelaySeconds`

**Provider factory:**
- `BuddyTranscriptionProviderFactory` — reads `VoiceTranscriptionProvider` from Info.plist via `AppBundleConfiguration`. Fallback chain: preferred → alternative → Apple Speech.

**Providers:**

| Provider | File | Mode | Fallback delay |
|----------|------|------|----------------|
| AssemblyAI | `AssemblyAIStreamingTranscriptionProvider.swift` | Real-time websocket streaming (`wss://streaming.assemblyai.com/v3/ws`) | 2.8s |
| OpenAI | `OpenAIAudioTranscriptionProvider.swift` | Upload-based (buffer → WAV → POST) | 8.0s |
| Apple Speech | `AppleSpeechTranscriptionProvider.swift` | Local on-device via SFSpeechRecognizer | 1.8s |

**Audio conversion:**
- `BuddyAudioConversionSupport.swift` — `BuddyPCM16AudioConverter` converts live mic buffers to PCM16 mono at 16kHz. `BuddyWAVFileBuilder` wraps PCM16 data in a WAV header for the upload-based OpenAI provider.

## Talks To [coverage: high — 5 sources]

- **Companion Engine** — `CompanionManager` binds to dictation manager state via Combine, receives finalized transcripts via `submitDraftText` callback
- **Cloudflare Worker** — AssemblyAI provider calls `/transcribe-token` to get short-lived websocket tokens (480s expiry)
- **External APIs** — AssemblyAI v3 websocket (streaming), OpenAI `/v1/audio/transcriptions` (upload), Apple Speech framework (local)
- **System APIs** — `AVAudioEngine` for mic capture, `AVCaptureDevice` for permission checks, `SFSpeechRecognizer` for Apple Speech permissions, `CGEvent` tap for system-wide shortcut monitoring

## API Surface [coverage: high — 4 sources]

**BuddyDictationManager (published state):**
- `isRecordingFromMicrophoneButton` / `isRecordingFromKeyboardShortcut`
- `isKeyboardShortcutSessionActiveOrFinalizing` / `isFinalizingTranscript` / `isPreparingToRecord`
- `currentAudioPowerLevel` / `recordedAudioPowerHistory` — for waveform visualization
- `transcriptionProviderDisplayName` / `lastErrorMessage` / `currentPermissionProblem`
- `isDictationInProgress` / `isActivelyRecordingAudio` — computed convenience

**BuddyDictationManager (methods):**
- `startPushToTalkFromKeyboardShortcut(currentDraftText:updateDraftText:submitDraftText:)`
- `stopPushToTalkFromKeyboardShortcut()`
- `startPersistentDictationFromMicrophoneButton(...)` / `stopPersistentDictationFromMicrophoneButton()`
- `cancelCurrentDictation(preserveDraftText:)`
- `requestInitialPushToTalkPermissionsIfNeeded()`
- `updateContextualKeyterms(_:)`
- `openRelevantPrivacySettings()`

**GlobalPushToTalkShortcutMonitor:**
- `shortcutTransitionPublisher` — Combine publisher of `.pressed` / `.released`
- `isShortcutCurrentlyPressed` — @Published for immediate UI feedback
- `start()` / `stop()`

## Data [coverage: medium — 3 sources]

- **Audio buffers:** PCM16 mono at 16kHz, streamed to provider in real-time (AssemblyAI/Apple) or buffered and uploaded as WAV (OpenAI)
- **Transcripts:** partial updates via `onTranscriptUpdate`, finalized via `onFinalTranscriptReady`
- **Keyterms:** contextual vocabulary hints passed to providers (AssemblyAI: `keyterms_prompt` query param, OpenAI: prompt text, Apple: not supported)
- **Base keyterms:** makesomething, Learning Buddy, Codex, Claude, Anthropic, OpenAI, SwiftUI, Xcode, Vercel, Next.js, localhost

## Key Decisions [coverage: high — 5 sources]

**Listen-only CGEvent tap for push-to-talk:** Uses `.listenOnly` option instead of AppKit's `NSEvent.addGlobalMonitorForEvents`. This is more reliable for modifier-only shortcuts (ctrl+option) detected in the background. The tap runs on `CFRunLoopGetMain()` so `isShortcutCurrentlyPressed` is always mutated on the main thread.

**Shared URLSession for AssemblyAI:** A single `URLSession(configuration: .default)` is reused across all streaming sessions. Creating and invalidating a URLSession per session corrupts the OS connection pool and causes "Socket is not connected" errors after rapid reconnections.

**Provider fallback chain:** If the preferred provider isn't configured, the factory falls back silently. AssemblyAI → OpenAI → Apple Speech. The default is AssemblyAI (`assemblyai` in Info.plist).

**Finalization timeout pattern:** Each provider has a `finalTranscriptFallbackDelaySeconds` — if the provider doesn't deliver a final transcript within that window after `requestFinalTranscript()`, the dictation manager uses whatever partial text is available. This prevents the UI from hanging if a provider's websocket drops.

**Duplicate permission prompt prevention:** A single `Task` is shared for in-flight permission requests. Rapid press-and-release doesn't fan out multiple macOS permission dialogs. A 1-second cooldown after completion prevents re-prompting during macOS's cache update lag.

**AssemblyAI turn-based transcripts:** Uses v3 API with `format_turns=true` and `speech_model=u3-rt-pro`. Tracks turns by `turn_order`, stores formatted vs unformatted variants, and composes the full transcript by joining committed turns + the active turn.

## Gotchas [coverage: high — 4 sources]

- **Quick press-and-release bug:** Without cancelling `pendingKeyboardShortcutStartTask` on release, a fast ctrl+option tap could leave the waveform overlay stuck on screen. The companion engine explicitly cancels the task on `.released`.
- **AssemblyAI token URL is a placeholder:** Ships as `your-worker-name.your-subdomain.workers.dev/transcribe-token`. Must be replaced with the deployed Worker URL.
- **OpenAI API key from Info.plist:** The OpenAI provider reads `OpenAIAPIKey` from the app bundle. If not set, `isConfigured` returns false and the provider is skipped.
- **Apple Speech requires Speech Recognition permission** in addition to Microphone. `requiresSpeechRecognitionPermission = true` triggers the extra permission check in `BuddyDictationManager`.
- **Audio power history:** Fixed at 44 samples, sampled every 0.07s. Baseline level is 0.02 (not 0). The history is displayed as the waveform visualization in the overlay.

## Sources

- [BuddyDictationManager.swift](../../leanring-buddy/BuddyDictationManager.swift)
- [BuddyTranscriptionProvider.swift](../../leanring-buddy/BuddyTranscriptionProvider.swift)
- [AssemblyAIStreamingTranscriptionProvider.swift](../../leanring-buddy/AssemblyAIStreamingTranscriptionProvider.swift)
- [OpenAIAudioTranscriptionProvider.swift](../../leanring-buddy/OpenAIAudioTranscriptionProvider.swift)
- [AppleSpeechTranscriptionProvider.swift](../../leanring-buddy/AppleSpeechTranscriptionProvider.swift)
- [BuddyAudioConversionSupport.swift](../../leanring-buddy/BuddyAudioConversionSupport.swift)
- [GlobalPushToTalkShortcutMonitor.swift](../../leanring-buddy/GlobalPushToTalkShortcutMonitor.swift)
