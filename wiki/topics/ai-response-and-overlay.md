---
topic: ai-response-and-overlay
last_compiled: 2026-04-10
sources: 10
status: active
---

# AI Response and Overlay

## Purpose [coverage: high — 10 sources]

This topic covers the output half of Clicky's interaction loop: sending screenshots + transcripts to Claude, streaming the response, speaking it via ElevenLabs TTS, and rendering the blue cursor overlay that can fly to and point at UI elements on screen. It also covers the menu bar panel UI, design system, and window management.

## Architecture [coverage: high — 10 sources]

**AI clients:**
- `ClaudeAPI.swift` (~291 lines) — Claude Messages API client with SSE streaming. Routes through the Cloudflare Worker proxy (`/chat`). Supports vision (multi-image), conversation history, and both streaming and non-streaming modes. Uses TLS warmup (HEAD request on init) to cache session tickets. Default model: `claude-sonnet-4-6`.
- `OpenAIAPI.swift` (~142 lines) — OpenAI Chat Completions client for vision. Direct API calls (not proxied). Same TLS warmup pattern. Default model: `gpt-5.2-2025-12-11`.
- `ElementLocationDetector.swift` (~335 lines) — Uses Claude's Computer Use API with `computer_20251124` beta to detect UI element coordinates. Picks the Anthropic-recommended resolution closest to the display's aspect ratio (1024x768, 1280x800, or 1366x768) to avoid distortion. Handles Retina scaling correctly using `NSBitmapImageRep` instead of `NSImage.lockFocus()`.

**TTS:**
- `ElevenLabsTTSClient.swift` (~81 lines) — sends text to the Worker proxy (`/tts`), receives audio/mpeg, plays via `AVAudioPlayer`. Uses `eleven_flash_v2_5` model with stability 0.5 / similarity_boost 0.75. Exposes `isPlaying` for transient cursor scheduling.

**Overlay system:**
- `OverlayWindow.swift` (~881 lines) — full-screen transparent `NSPanel` hosting the blue cursor companion. Non-activating, joins all Spaces, never steals focus. Contains `BlueCursorView` (the triangle cursor that follows the mouse), waveform visualization, response text bubble, spinner states, and the pointing flight animation (bezier arc to target element). Handles multi-monitor coordinate mapping.
- `CompanionResponseOverlay.swift` (~217 lines) — SwiftUI view for the response text bubble and waveform displayed next to the cursor.

**Menu bar panel:**
- `MenuBarPanelManager.swift` (~243 lines) — `NSStatusItem` for the menu bar icon + custom borderless `NSPanel` for the floating control panel. Click-outside-to-dismiss via global event monitor. Non-activating panel.
- `CompanionPanelView.swift` (~761 lines) — SwiftUI panel content: companion status, push-to-talk instructions, model picker (Sonnet/Opus), onboarding permissions UI, email capture, DM feedback button, "Watch Onboarding Again" link, and quit button. Uses `DS` design system.

**Supporting:**
- `DesignSystem.swift` (~880 lines) — design tokens: `DS.Colors`, `DS.CornerRadius`, `DS.Fonts`, etc. Dark aesthetic throughout.
- `WindowPositionManager.swift` (~262 lines) — window placement logic, Screen Recording permission detection, accessibility permission helpers.

## Talks To [coverage: high — 5 sources]

- **Companion Engine** — receives transcripts and screen captures, publishes voiceState and pointing coordinates back
- **Cloudflare Worker** — `/chat` for Claude streaming, `/tts` for ElevenLabs
- **Anthropic API** (direct, for Computer Use) — `ElementLocationDetector` calls `api.anthropic.com/v1/messages` directly with `anthropic-beta: computer-use-2025-11-24`
- **System APIs** — `NSPanel` (AppKit), ScreenCaptureKit permissions, `AVAudioPlayer`

## API Surface [coverage: high — 6 sources]

**ClaudeAPI:**
- `analyzeImageStreaming(images:systemPrompt:conversationHistory:userPrompt:onTextChunk:) async throws -> (text, duration)` — SSE streaming vision request
- `analyzeImage(images:systemPrompt:conversationHistory:userPrompt:) async throws -> (text, duration)` — non-streaming fallback
- `model: String` — mutable, switched via panel UI

**ElevenLabsTTSClient:**
- `speakText(_ text:) async throws` — sends text, plays audio
- `isPlaying: Bool` — whether audio is playing
- `stopPlayback()` — immediate stop

**ElementLocationDetector:**
- `detectElementLocation(screenshotData:userQuestion:displayWidthInPoints:displayHeightInPoints:) async -> CGPoint?` — returns display-local AppKit coords

**Pointing protocol (in Claude's response):**
- `[POINT:x,y:label]` — point at element on cursor screen
- `[POINT:x,y:label:screenN]` — point at element on specific screen
- `[POINT:none]` — no pointing
- Parsed by `CompanionManager.parsePointingCoordinates(from:)` → `PointingParseResult`

**Coordinate pipeline:** Claude's pixel coords (screenshot space) → scale to display points → flip Y for AppKit → add display frame origin → `detectedElementScreenLocation` published

## Data [coverage: medium — 3 sources]

- **Images sent to Claude:** JPEG screenshots from all connected displays, capped at 1280px on longest dimension, labeled with pixel dimensions and cursor screen indicator
- **System prompt:** ~2000 chars defining Clicky's personality (casual, lowercase, warm, no emojis, write for the ear, pointing instructions with coordinate format)
- **Conversation history:** max 10 user/assistant pairs, point tags stripped from stored responses
- **TTS audio:** audio/mpeg downloaded in full before playback (not true streaming)

## Key Decisions [coverage: high — 5 sources]

**SSE streaming for Claude, not for TTS:** Claude responses stream progressively via Server-Sent Events so the UI can show a spinner with accurate timing. TTS downloads the full audio before playing — the `eleven_flash_v2_5` model is fast enough that this doesn't add perceptible latency.

**Custom NSPanel for overlay and menu bar:** Both the cursor overlay and the menu bar panel use `NSPanel` (not `NSWindow`) because panels can be non-activating — they never steal keyboard focus from the user's current app. The overlay is also set to join all Spaces.

**Point tag at end of response:** Claude appends `[POINT:x,y:label]` at the very end of its response text. The tag is parsed and stripped before TTS. This means pointing coordinates are only available after the full response streams in.

**Computer Use aspect ratio matching:** `ElementLocationDetector` picks the Anthropic-recommended resolution closest to the actual display aspect ratio rather than always using 1024x768. Most Macs are 16:10 → 1280x800. This significantly improves X-axis coordinate accuracy.

**Retina bitmap fix:** Uses `NSBitmapImageRep` directly instead of `NSImage.lockFocus()` for resizing. On Retina displays, `lockFocus` creates a bitmap at 2x the declared size, causing Claude's pixel-counting to return coordinates in the wrong scale.

**TLS session caching:** Both `ClaudeAPI` and `OpenAIAPI` use `URLSessionConfiguration.default` (not `.ephemeral`) and fire a HEAD warmup request. Ephemeral sessions do a full TLS handshake on every request, causing transient `-1200` errors with large image payloads.

**Fallback TTS on credits exhaustion:** If ElevenLabs fails, `NSSpeechSynthesizer` speaks a hardcoded message asking the user to DM Farza.

## Gotchas [coverage: high — 5 sources]

- **Worker URL placeholders:** `ClaudeAPI` and `ElevenLabsTTSClient` are initialized with `your-worker-name.your-subdomain.workers.dev`. Must be replaced.
- **ElementLocationDetector uses direct Anthropic API** — not the Worker proxy. Requires a raw `ANTHROPIC_API_KEY` in the app, which contradicts the proxy architecture. Currently used only for the onboarding demo, not the main pipeline.
- **OpenAI model version:** Hardcoded to `gpt-5.2-2025-12-11` — needs updating when models change.
- **Max tokens:** Claude streaming uses 1024 max_tokens, non-streaming uses 256. OpenAI uses `max_completion_tokens: 600`.
- **Image MIME detection:** Both `ClaudeAPI` and `ElementLocationDetector` check the first 4 bytes for PNG signature. Everything else defaults to JPEG.
- **Response text vs spoken text:** The full response includes the `[POINT:...]` tag, but `spokenText` has it stripped. Conversation history stores `spokenText` to avoid confusing future context.

## Sources

- [ClaudeAPI.swift](../../leanring-buddy/ClaudeAPI.swift)
- [OpenAIAPI.swift](../../leanring-buddy/OpenAIAPI.swift)
- [ElevenLabsTTSClient.swift](../../leanring-buddy/ElevenLabsTTSClient.swift)
- [ElementLocationDetector.swift](../../leanring-buddy/ElementLocationDetector.swift)
- [OverlayWindow.swift](../../leanring-buddy/OverlayWindow.swift)
- [CompanionResponseOverlay.swift](../../leanring-buddy/CompanionResponseOverlay.swift)
- [CompanionPanelView.swift](../../leanring-buddy/CompanionPanelView.swift)
- [MenuBarPanelManager.swift](../../leanring-buddy/MenuBarPanelManager.swift)
- [DesignSystem.swift](../../leanring-buddy/DesignSystem.swift)
- [WindowPositionManager.swift](../../leanring-buddy/WindowPositionManager.swift)
