---
concept: Cloudflare Worker Proxy Pattern
last_compiled: 2026-04-10
topics_connected: [worker-proxy, ai-integration, voice-pipeline, infrastructure]
status: active
---

# Cloudflare Worker Proxy Pattern

## Pattern

Clicky routes ALL external API calls through a single Cloudflare Worker so that API keys never ship in the app binary. This is a security-first architectural decision that affects every feature touching an external service: Claude chat, ElevenLabs TTS, and AssemblyAI transcription all go through the same proxy.

The one known exception is `ElementLocationDetector`, which calls the Anthropic API directly — this is flagged as a gotcha in the ai-integration article and represents a potential key-exposure vector if the app were reverse-engineered.

## Instances

- **worker-proxy**: The Worker itself has 3 routes (`/chat`, `/tts`, `/transcribe-token`), each forwarding to a different upstream API. Secrets are stored in Cloudflare, vars in `wrangler.toml`.
- **ai-integration**: `ClaudeAPI.swift` and `ElevenLabsTTSClient.swift` both point to the Worker URL. The Worker URL is hardcoded in two Swift files — grep for "clicky-proxy" to find them.
- **voice-pipeline**: `AssemblyAIStreamingTranscriptionProvider` fetches a temporary websocket token via the Worker's `/transcribe-token` route, then connects directly to AssemblyAI's websocket (the Worker only brokers the token, not the stream).
- **infrastructure**: The release pipeline doesn't embed API keys — they only exist as Cloudflare secrets and in the local `.dev.vars` file (gitignored).

## What This Means

Adding any new external API integration requires: (1) adding a new Worker route, (2) storing the key as a Cloudflare secret, (3) deploying the Worker before using the feature. This is more friction than embedding keys directly, but it's the right tradeoff for a distributed macOS app. The `ElementLocationDetector` exception should probably be fixed.

## Sources

- [worker-proxy](../topics/worker-proxy.md)
- [ai-integration](../topics/ai-integration.md)
- [voice-pipeline](../topics/voice-pipeline.md)
- [infrastructure](../topics/infrastructure.md)
