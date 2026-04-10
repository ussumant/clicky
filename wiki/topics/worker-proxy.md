---
topic: worker-proxy
last_compiled: 2026-04-10
sources: 3
status: active
---

# Worker Proxy

## Purpose

The Cloudflare Worker proxy (`clicky-proxy`) keeps every third-party API key out of the macOS app binary. The app never calls Anthropic, ElevenLabs, or AssemblyAI directly — all traffic goes through the worker, which injects the real credentials from Cloudflare secrets at the edge. This means a decompiled or inspected build of Clicky reveals no usable secrets.

## Architecture

```
macOS App (Clicky)
        │
        │  POST /chat, /tts, /transcribe-token
        ▼
Cloudflare Worker (clicky-proxy)
        │
        ├──► api.anthropic.com/v1/messages          (Claude)
        ├──► api.elevenlabs.io/v1/text-to-speech    (ElevenLabs)
        └──► streaming.assemblyai.com/v3/token      (AssemblyAI)
```

The worker is a single TypeScript file (`worker/src/index.ts`, ~142 lines) with no runtime dependencies — only the `wrangler` dev toolchain as a devDependency. The `Env` interface declares the four bindings the worker reads at runtime: `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID`, and `ASSEMBLYAI_API_KEY`.

The app hardcodes the worker's base URL in two places:

- [`CompanionManager.swift`](../../leanring-buddy/CompanionManager.swift) — `workerBaseURL` static constant (line 73), used for `/chat` and `/tts`
- [`AssemblyAIStreamingTranscriptionProvider.swift`](../../leanring-buddy/AssemblyAIStreamingTranscriptionProvider.swift) — `tokenProxyURL` static constant (line 22), used for `/transcribe-token`

To find all references when the worker URL changes, grep for `clicky-proxy` or `workers.dev` across Swift files.

## Talks To

| Upstream | URL | Auth header |
|----------|-----|-------------|
| Anthropic | `https://api.anthropic.com/v1/messages` | `x-api-key: $ANTHROPIC_API_KEY` |
| ElevenLabs | `https://api.elevenlabs.io/v1/text-to-speech/{ELEVENLABS_VOICE_ID}` | `xi-api-key: $ELEVENLABS_API_KEY` |
| AssemblyAI | `https://streaming.assemblyai.com/v3/token?expires_in_seconds=480` | `authorization: $ASSEMBLYAI_API_KEY` |

## API Surface

The worker accepts only `POST` requests. Any other HTTP method returns `405 Method not allowed`. Unknown paths return `404 Not found`. Per-route errors are caught, logged with `console.error`, and returned as `500` with a JSON body `{ "error": "..." }`.

### `POST /chat`

Proxies to the Anthropic Messages API with streaming SSE.

- **Request**: passes the raw request body through unchanged to Anthropic; the app is responsible for constructing the full Anthropic messages payload (model, system prompt, messages array, `stream: true`, etc.)
- **Auth added**: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`
- **Success response**: streams Anthropic's response body as-is. Content-type forwarded from upstream (defaults to `text/event-stream`). `cache-control: no-cache` added.
- **Error response**: if Anthropic returns a non-2xx, the worker forwards the upstream status code and body verbatim (not wrapped in 500).

### `POST /tts`

Proxies to ElevenLabs text-to-speech.

- **Request**: passes raw request body through. The voice ID comes from the `ELEVENLABS_VOICE_ID` env var — the app does not send it.
- **Auth added**: `xi-api-key`, `accept: audio/mpeg`, `content-type: application/json`
- **Success response**: streams the audio body. Content-type forwarded from upstream (defaults to `audio/mpeg`).
- **Error response**: if ElevenLabs returns a non-2xx, the upstream status code and body are forwarded unchanged.

### `POST /transcribe-token`

Fetches a short-lived AssemblyAI websocket token. The upstream call is a `GET` even though the app reaches this route via `POST` (the worker ignores the app's request body entirely).

- **Request**: no body used. Worker calls `GET https://streaming.assemblyai.com/v3/token?expires_in_seconds=480`
- **Auth added**: `authorization: $ASSEMBLYAI_API_KEY`
- **Success response**: `200` with `content-type: application/json`. The token expires in 480 seconds (8 minutes).
- **Error response**: upstream status code and body forwarded unchanged.

## Data

| Secret / Var | Storage | Notes |
|---|---|---|
| `ANTHROPIC_API_KEY` | Cloudflare secret | Never in code or wrangler.toml |
| `ASSEMBLYAI_API_KEY` | Cloudflare secret | Never in code or wrangler.toml |
| `ELEVENLABS_API_KEY` | Cloudflare secret | Never in code or wrangler.toml |
| `ELEVENLABS_VOICE_ID` | `wrangler.toml` `[vars]` | Committed; value `kPzsL2i3teMYv0FxEYQ6`. Non-secret — it's a public voice ID, not a credential. |

For local development, secrets go in `worker/.dev.vars` (gitignored). The `ELEVENLABS_VOICE_ID` var is available automatically from `wrangler.toml`.

## Key Decisions

**Pass-through body, not re-parsing.** For `/chat` and `/tts`, the worker reads the body as raw text and forwards it to the upstream without parsing or validating JSON. This keeps the worker zero-opinion about the payload and means new Anthropic/ElevenLabs parameters are available without worker changes.

**Separate token endpoint instead of in-app key.** The AssemblyAI key is kept server-side, and the app requests a short-lived websocket token (480 s) per session. The token, not the key, is embedded in the AssemblyAI websocket URL. This prevents key leakage even if the token is somehow intercepted.

**Voice ID in vars, not secrets.** `ELEVENLABS_VOICE_ID` is in `wrangler.toml` as a plain var. Voice IDs are not sensitive — they are publicly addressable identifiers in ElevenLabs. Keeping it in `wrangler.toml` (not a Cloudflare secret) makes it visible and easy to change during deploys without CLI secret management.

**No CORS, no auth on the worker.** The worker is unauthenticated — anyone who knows the URL can call it. This is an acceptable trade-off for a personal-use app, but it means the upstream API key costs are shared with any caller. If the worker URL leaks, rotate the upstream secrets via `wrangler secret put`.

**`anthropic-version` pinned to `2023-06-01`.** This is the stable Anthropic API version. Bumping it requires a worker redeploy.

## Gotchas

- **Method check fires before path check.** The `POST`-only guard runs before routing. A `GET /transcribe-token` from the app will get a `405`, not a `404`. This is intentional — `/transcribe-token` looks like a `GET` operation but the app must call it with `POST`.
- **Error forwarding, not wrapping.** For upstream API errors (4xx from Anthropic/ElevenLabs/AssemblyAI), the worker forwards the upstream status code and body directly. The app receives the Anthropic 4xx, not a generic 500. The try/catch only fires on network-level or unexpected JS errors.
- **Voice ID not in the request.** The ElevenLabs voice ID is server-side. If the app sends a voice ID in the body, ElevenLabs ignores it — the URL path is controlled by the worker.
- **No retry logic.** The worker makes exactly one upstream request per inbound request. Retries, timeouts, and backoff are the app's responsibility.
- **Two hardcoded URL constants in Swift.** If the worker is redeployed under a new URL, both `CompanionManager.workerBaseURL` and `AssemblyAIStreamingTranscriptionProvider.tokenProxyURL` must be updated and the app rebuilt.
- **Compatibility date `2024-01-01`.** Set in `wrangler.toml`. Advancing this may change Cloudflare runtime behavior; test locally with `wrangler dev` before deploying.

## Sources

- [`worker/src/index.ts`](../../worker/src/index.ts) — full worker implementation
- [`worker/wrangler.toml`](../../worker/wrangler.toml) — worker name, entrypoint, compatibility date, vars
- [`worker/package.json`](../../worker/package.json) — scripts and devDependencies
- [`leanring-buddy/CompanionManager.swift`](../../leanring-buddy/CompanionManager.swift) — `workerBaseURL` constant (line 73)
- [`leanring-buddy/AssemblyAIStreamingTranscriptionProvider.swift`](../../leanring-buddy/AssemblyAIStreamingTranscriptionProvider.swift) — `tokenProxyURL` constant (line 22)
