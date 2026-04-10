---
topic: companion-engine
last_compiled: 2026-04-10
sources: 5
status: active
---

# Companion Engine

## Purpose [coverage: high — 5 sources]

The companion engine is the central nervous system of Clicky — a macOS menu bar AI companion that sees your screen, listens to your voice, and responds with speech and cursor pointing. It manages the entire lifecycle: app launch, permission handling, onboarding, push-to-talk orchestration, Claude API calls, ElevenLabs TTS playback, and element pointing coordination. Everything in the app flows through `CompanionManager`, which acts as the state machine connecting voice input, AI responses, and visual output.

The app runs as a menu bar-only process (`LSUIElement=true`) — no dock icon, no main window. `CompanionAppDelegate` bootstraps the system on launch: configures PostHog analytics, creates the `MenuBarPanelManager` for the status bar icon, and calls `companionManager.start()` to begin permission polling and shortcut monitoring. If onboarding is incomplete or permissions are missing, the panel auto-opens.

## Architecture [coverage: high — 5 sources]

**Entry point:** `leanring_buddyApp.swift` — SwiftUI `@main` app with an empty `Settings` scene (satisfies SwiftUI's requirement but is never shown). The real work happens in `CompanionAppDelegate`.

**State machine:** `CompanionManager.swift` (~1026 lines) — the largest file in the codebase. Owns:
- `voiceState: CompanionVoiceState` (idle/listening/processing/responding)
- `buddyDictationManager` — push-to-talk voice capture
- `globalPushToTalkShortcutMonitor` — system-wide keyboard shortcut
- `overlayWindowManager` — blue cursor overlay
- `claudeAPI` / `elevenLabsTTSClient` — lazily initialized AI services
- `conversationHistory` — last 10 exchanges for contextual memory
- Permission state (accessibility, screen recording, mic, screen content)
- Onboarding state (video player, music, demo interaction, prompt streaming)

**Screen capture:** `CompanionScreenCaptureUtility.swift` — standalone multi-monitor JPEG capture using ScreenCaptureKit. Excludes the app's own windows. Labels each screen with cursor position, pixel dimensions, and display frame. Sorts so cursor screen is always first.

**Analytics:** `ClickyAnalytics.swift` — centralized PostHog wrapper. Tracks app_opened, onboarding events (started/replayed/video_completed/demo_triggered), permission grants, push-to-talk start/release, user_message_sent, ai_response_received, element_pointed, and error events.

**Config:** `AppBundleConfiguration.swift` — reads runtime values from Info.plist (e.g., `VoiceTranscriptionProvider`).

**Startup flow:**
1. `applicationDidFinishLaunching` → configure PostHog → create MenuBarPanelManager → `companionManager.start()`
2. `start()` → refresh permissions → start polling → bind voice/shortcut observers → eagerly touch ClaudeAPI for TLS warmup
3. If onboarded + all permissions + cursor enabled → show overlay immediately

## Talks To [coverage: high — 5 sources]

- **Voice Pipeline** — `BuddyDictationManager` for push-to-talk recording, `GlobalPushToTalkShortcutMonitor` for system-wide shortcut detection
- **AI + TTS** — `ClaudeAPI` for vision chat (streaming SSE), `ElevenLabsTTSClient` for speech playback, `ElementLocationDetector` for Computer Use pointing (legacy, not actively used in main pipeline)
- **UI** — `OverlayWindowManager` for cursor overlay, `MenuBarPanelManager` for status bar panel, `NotificationCenter` for cross-component communication (`.clickyDismissPanel`)
- **External services** — Cloudflare Worker (`clicky-proxy`) for all API calls, FormSpark for email submission, Mux for onboarding video streaming
- **System APIs** — ScreenCaptureKit, AVFoundation, SMAppService (login item), PostHog SDK

## API Surface [coverage: high — 3 sources]

**CompanionManager (published state):**
- `voiceState` — current voice pipeline state
- `lastTranscript` — most recent user transcript
- `currentAudioPowerLevel` — live microphone level for waveform
- `has{Accessibility,ScreenRecording,Microphone,ScreenContent}Permission` — per-permission status
- `allPermissionsGranted` — aggregated permission check
- `isOverlayVisible` — whether the cursor is showing
- `selectedModel` — Claude model (Sonnet/Opus), persisted to UserDefaults
- `isClickyCursorEnabled` — show/hide toggle, persisted
- `hasCompletedOnboarding` — first-launch flag, persisted
- `detectedElementScreenLocation/DisplayFrame/BubbleText` — coordinates for cursor pointing animation

**CompanionManager (methods):**
- `start()` / `stop()` — lifecycle
- `setSelectedModel(_:)` — switch Claude model
- `setClickyCursorEnabled(_:)` — toggle cursor visibility
- `triggerOnboarding()` / `replayOnboarding()` — onboarding flows
- `requestScreenContentPermission()` — trigger ScreenCaptureKit picker
- `submitEmail(_:)` — FormSpark + PostHog identify

**CompanionScreenCaptureUtility:**
- `captureAllScreensAsJPEG() async throws -> [CompanionScreenCapture]`

## Data [coverage: medium — 3 sources]

- **UserDefaults keys:** `selectedClaudeModel`, `isClickyCursorEnabled`, `hasCompletedOnboarding`, `hasSubmittedEmail`, `hasScreenContentPermission`
- **In-memory:** `conversationHistory` (max 10 exchanges), `voiceState`, permission flags
- **PostHog:** anonymous events tracked via `ClickyAnalytics`

## Key Decisions [coverage: high — 3 sources]

**Menu bar-only architecture:** `LSUIElement=true` removes the dock icon and app menu. The app lives entirely in the status bar. An empty SwiftUI `Settings` scene satisfies the framework's requirement for at least one scene.

**Login item registration:** Uses `SMAppService.mainApp` so the app appears in System Settings > Login Items, giving the user control.

**Permission polling:** All permissions are refreshed every 1.5 seconds via a timer. This is necessary because macOS doesn't provide real-time permission change callbacks. Screen Recording requires an app restart to take effect.

**TLS warmup:** ClaudeAPI is eagerly initialized on `start()` and fires a HEAD request to cache the TLS session ticket. This prevents cold handshake failures when the first real request carries a large image payload.

**Conversation history limit:** Capped at 10 exchanges to prevent unbounded context growth in Claude API calls.

**Transient cursor mode:** When "Show Clicky" is off, pressing the hotkey fades in the cursor for the duration of the interaction (recording → response → TTS → pointing), then fades it out after 1 second of inactivity. This is cancelled if the user starts another interaction.

**Onboarding music:** Plays `ff.mp3` (Besaid theme) at 30% volume for 90 seconds with a 3-second fade-out.

## Gotchas [coverage: high — 3 sources]

- **Do NOT run `xcodebuild` from the terminal** — it invalidates TCC permissions (screen recording, accessibility) and the app will need re-granting.
- **macOS permission cache lag:** After granting mic/speech permission, macOS briefly reports `.notDetermined`. The dictation manager debounces re-requests for 1 second after completion.
- **Sparkle updater is commented out** — `startSparkleUpdater()` is called but the line is commented in `applicationDidFinishLaunching`. The `SUFeedURL` and `SUPublicEDKey` are still in Info.plist.
- **"leanring" typo is intentional** — the directory and scheme name. Do not rename.
- **Screen content permission is sticky** — once approved via `SCShareableContent`, it's persisted to UserDefaults and never re-prompted.
- **Worker URL placeholder:** The source ships with `your-worker-name.your-subdomain.workers.dev` — users must replace this with their deployed Worker URL.

## Sources

- [leanring_buddyApp.swift](../../leanring-buddy/leanring_buddyApp.swift)
- [CompanionManager.swift](../../leanring-buddy/CompanionManager.swift)
- [CompanionScreenCaptureUtility.swift](../../leanring-buddy/CompanionScreenCaptureUtility.swift)
- [ClickyAnalytics.swift](../../leanring-buddy/ClickyAnalytics.swift)
- [AppBundleConfiguration.swift](../../leanring-buddy/AppBundleConfiguration.swift)
