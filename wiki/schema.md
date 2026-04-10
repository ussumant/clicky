# Clicky Wiki Schema

## Topics

| Slug | Description | Key Files |
|------|-------------|-----------|
| `companion-engine` | Core state machine, app lifecycle, screen capture, analytics, onboarding | leanring_buddyApp.swift, CompanionManager.swift, CompanionScreenCaptureUtility.swift, ClickyAnalytics.swift, AppBundleConfiguration.swift |
| `voice-and-transcription` | Push-to-talk capture, transcription providers (AssemblyAI/OpenAI/Apple), audio conversion, global shortcut monitor | BuddyDictationManager.swift, BuddyTranscriptionProvider.swift, AssemblyAI*.swift, OpenAI*.swift, AppleSpeech*.swift, BuddyAudioConversionSupport.swift, GlobalPushToTalkShortcutMonitor.swift |
| `ai-response-and-overlay` | Claude/OpenAI vision API, ElevenLabs TTS, element pointing, cursor overlay, menu bar panel, design system | ClaudeAPI.swift, OpenAIAPI.swift, ElevenLabsTTSClient.swift, ElementLocationDetector.swift, OverlayWindow.swift, CompanionPanelView.swift, CompanionResponseOverlay.swift, MenuBarPanelManager.swift, DesignSystem.swift, WindowPositionManager.swift |
| `worker-proxy` | Cloudflare Worker API proxy (chat, TTS, transcribe-token routes) | worker/src/index.ts, worker/wrangler.toml, worker/package.json |

## Concepts

| Slug | Description | Connects |
|------|-------------|----------|
| `nswindow-focus-management` | Non-activating window pattern across all UI surfaces | companion-engine, ai-response-and-overlay, voice-and-transcription |
| `cloudflare-worker-proxy-pattern` | All API keys proxied through Cloudflare Worker | worker-proxy, ai-response-and-overlay, voice-and-transcription |

## Naming Conventions

- Topic slugs: lowercase-kebab-case matching the functional area
- The "leanring" typo is intentional/legacy — do not rename
- Concept slugs describe the pattern, not a specific file

## Evolution Log

- 2026-04-10: Initial schema generated from 6 topics, 2 concepts
- 2026-04-10: Restructured to 4 feature-flow topics (companion-engine, voice-and-transcription, ai-response-and-overlay, worker-proxy). Removed app-core, voice-pipeline, ai-integration, overlay-ui, infrastructure.
