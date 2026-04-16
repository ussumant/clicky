# Hi, this is Clicky.
It's an AI teacher that lives as a buddy next to your cursor. It can see your screen, talk to you, and even point at stuff. Kinda like having a real teacher next to you.

## Codex Hackathon: Pawscript

This fork adds **Pawscript**, a tutorial-to-execution layer for Clicky. Paste a YouTube tutorial or a how-to doc, and Spanks turns it into a Workflow Recorder-compatible skill that can be replayed in two demo modes:

- **Guide me** — Spanks watches your screen, narrates the current step, points at likely targets, and moves the cursor.
- **Watch Spanks do it** — Browser Use opens a visible browser and executes the same skill.

The canonical bundled fallback is OpenAI's “Designing delightful frontends with GPT-5.4” guide, so the hackathon demo works even if the hero YouTube URL fails validation.

For the hackathon slice, **Browser Use is the primary automation engine** because Pawscript v1 focuses on browser tutorials: it can open a visible browser, click/type through the extracted skill, and stream progress back to Spanks. Full-desktop computer-use systems like [CUA](https://github.com/trycua/cua) are a strong roadmap fit for non-browser tutorials, but they add sandbox and host-control setup risk that is too high for the 2-minute demo. Keep the Pawscript executor boundary skill-based so Browser Use can later sit beside a `CUAExecutor` or another computer-use backend without changing the WR-compatible `SkillStep[]` contract.

Download it [here](https://www.clicky.so/) for free.

Here's the [original tweet](https://x.com/FarzaTV/status/2041314633978659092) that kinda blew up for a demo for more context.

![Clicky — an ai buddy that lives on your mac](clicky-demo.gif)

This is the open-source version of Clicky for those that want to hack on it, build their own features, or just see how it works under the hood.

## Get started with Claude Code

The fastest way to get this running is with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Once you get Claude running, paste this:

```
Hi Claude.

Clone https://github.com/farzaa/clicky.git into my current directory.

Then read the CLAUDE.md. I want to get Clicky running locally on my Mac.

Help me set up everything — the Cloudflare Worker with my own API keys, the proxy URLs, and getting it building in Xcode. Walk me through it.
```

That's it. It'll clone the repo, read the docs, and walk you through the whole setup. Once you're running you can just keep talking to it — build features, fix bugs, whatever. Go crazy.

## Manual setup

If you want to do it yourself, here's the deal.

### Prerequisites

- macOS 14.2+ (for ScreenCaptureKit)
- Xcode 15+
- Node.js 18+ (for the Cloudflare Worker)
- A [Cloudflare](https://cloudflare.com) account (free tier works)
- API keys for: [Anthropic](https://console.anthropic.com), [AssemblyAI](https://www.assemblyai.com), [ElevenLabs](https://elevenlabs.io)
- Optional: an [OpenAI](https://platform.openai.com) API key for OpenAI voice and transcription from the in-app settings panel.

### OpenAI voice setup

Open the Clicky menu bar panel, expand **OpenAI**, paste your OpenAI API key, and hit **Save key**. The key is stored in macOS Keychain, not `UserDefaults`.

Then set **Voice** to **OpenAI** to power spoken responses with OpenAI text-to-speech. You can also set **Listen** to **OpenAI** if you want OpenAI transcription instead of AssemblyAI or local Apple Speech.

### Pawscript demo setup

Pawscript expects demo tools to be preinstalled; it does not auto-install them from the app.

```bash
brew install yt-dlp
uv venv --python 3.12
source .venv/bin/activate
uv pip install browser-use openai python-dotenv
uvx browser-use install
```

If you use a custom Python environment, set `PAWSCRIPT_PYTHON` to its Python binary before launching the app from Xcode.

Demo flow:

1. Paste `https://www.youtube.com/watch?v=Q_bd7BFh0XY`.
2. Click **Extract skill**.
3. Click **Guide me** to let Spanks point and move the cursor while you do the steps.
4. Click **Stuck** once to record a `human-observation` gotcha.
5. Click **Watch Spanks do it** to run the same skill through Browser Use in a visible browser.

### 1. Set up the Cloudflare Worker

The Worker is a tiny proxy that holds your API keys. The app talks to the Worker, the Worker talks to the APIs. This way your keys never ship in the app binary.

```bash
cd worker
npm install
```

Now add your secrets. Wrangler will prompt you to paste each one:

```bash
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ASSEMBLYAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
```

For the ElevenLabs voice ID, open `wrangler.toml` and set it there (it's not sensitive):

```toml
[vars]
ELEVENLABS_VOICE_ID = "your-voice-id-here"
```

Deploy it:

```bash
npx wrangler deploy
```

It'll give you a URL like `https://your-worker-name.your-subdomain.workers.dev`. Copy that.

### 2. Run the Worker locally (for development)

If you want to test changes to the Worker without deploying:

```bash
cd worker
npx wrangler dev
```

This starts a local server (usually `http://localhost:8787`) that behaves exactly like the deployed Worker. You'll need to create a `.dev.vars` file in the `worker/` directory with your keys:

```
ANTHROPIC_API_KEY=sk-ant-...
ASSEMBLYAI_API_KEY=...
ELEVENLABS_API_KEY=...
ELEVENLABS_VOICE_ID=...
```

Then update the proxy URLs in the Swift code to point to `http://localhost:8787` instead of the deployed Worker URL while developing. Grep for `clicky-proxy` to find them all.

### 3. Update the proxy URLs in the app

The app has the Worker URL hardcoded in a few places. Search for `your-worker-name.your-subdomain.workers.dev` and replace it with your Worker URL:

```bash
grep -r "clicky-proxy" leanring-buddy/
```

You'll find it in:
- `CompanionManager.swift` — Claude chat + ElevenLabs TTS
- `AssemblyAIStreamingTranscriptionProvider.swift` — AssemblyAI token endpoint

### 4. Open in Xcode and run

```bash
open leanring-buddy.xcodeproj
```

In Xcode:
1. Select the `leanring-buddy` scheme (yes, the typo is intentional, long story)
2. Set your signing team under Signing & Capabilities
3. Hit **Cmd + R** to build and run

The app will appear in your menu bar (not the dock). Click the icon to open the panel, grant the permissions it asks for, and you're good.

### Permissions the app needs

- **Microphone** — for push-to-talk voice capture
- **Accessibility** — for the global keyboard shortcut (Control + Option)
- **Screen Recording** — for taking screenshots when you use the hotkey
- **Screen Content** — for ScreenCaptureKit access

## Architecture

If you want the full technical breakdown, read `CLAUDE.md`. But here's the short version:

**Menu bar app** (no dock icon) with two `NSPanel` windows — one for the control panel dropdown, one for the full-screen transparent cursor overlay. Push-to-talk streams audio over a websocket to AssemblyAI, sends the transcript + screenshot to Claude via streaming SSE, and plays the response through ElevenLabs TTS. Claude can embed `[POINT:x,y:label:screenN]` tags in its responses to make the cursor fly to specific UI elements across multiple monitors. All three APIs are proxied through a Cloudflare Worker.

## Project structure

```
leanring-buddy/          # Swift source (yes, the typo stays)
  CompanionManager.swift    # Central state machine
  CompanionPanelView.swift  # Menu bar panel UI
  ClaudeAPI.swift           # Claude streaming client
  ElevenLabsTTSClient.swift # Text-to-speech playback
  OverlayWindow.swift       # Blue cursor overlay
  AssemblyAI*.swift         # Real-time transcription
  BuddyDictation*.swift     # Push-to-talk pipeline
worker/                  # Cloudflare Worker proxy
  src/index.ts              # Three routes: /chat, /tts, /transcribe-token
CLAUDE.md                # Full architecture doc (agents read this)
```

## Contributing

PRs welcome. If you're using Claude Code, it already knows the codebase — just tell it what you want to build and point it at `CLAUDE.md`.

Got feedback? DM me on X [@farzatv](https://x.com/farzatv).
