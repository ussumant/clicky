# Clicky + Pawscript

**Built during OpenAI Codex Hackathon demo day.**

Clicky is a macOS menu bar companion that can see your screen, listen when you press a hotkey, talk back, and point at the thing it is explaining. This fork adds **Pawscript**: a tutorial-to-execution layer that turns saved YouTube videos and how-to docs into active guided sessions.

The product idea is simple:

> I have too many bookmarks, docs, and videos saved forever. Pawscript turns one of them into something I actually do.

Instead of watching a tutorial in one tab and working in another, Spanks the pixel cat extracts the tutorial into a Workflow Recorder-compatible skill, walks beside you step-by-step, captures gotchas when you get stuck, and can hand browser-safe work to an agent path.

![Clicky demo](clicky-demo.gif)

## Demo-Day Story

The demo story is **saved tutorial → cat-guided execution**.

1. Paste a tutorial or doc URL into Pawscript.
2. Spanks loads or extracts a skill: steps, prerequisites, gotchas, acceptance criteria, tools, and reference values.
3. You click **Guide me**.
4. Spanks opens or points at the right place, narrates the current step, and shows exactly what is “good enough” to move on.
5. If the workflow needs login, a canvas, or a human choice, Spanks pauses instead of pretending.
6. If you get stuck, click **Stuck** and Pawscript saves a gotcha with context.
7. The same skill can also be sent to **Watch Spanks do it**, the Browser Use agent path, for browser automation.

The hackathon framing:

> Tutorials should not die as passive tabs. They should become reusable execution skills for humans and agents.

## Hero Demo

The primary demo source is this Paper.design YouTube tutorial:

```text
https://www.youtube.com/watch?v=Ny3rvJWT5PM
```

For stage reliability, the repo includes a bundled validated Paper skill:

```text
leanring-buddy/PawscriptSkills/paper-shaders-design-guide.json
```

That skill guides the user through building an **Ask AI shader card** in Paper:

1. Open an editable Paper canvas.
2. Handle login or canvas setup.
3. Draw the dark rounded card.
4. Add the left circle.
5. Add Liquid Metal to the circle.
6. Add the Ask AI text.
7. Add a sparkle icon.
8. Add Neuron Noise to the text.
9. Add the Pulsing Border.
10. Verify the final graphic.

Each step includes concrete substeps plus a `Good enough:` checkpoint, so the demo does not depend on fragile perfect automation inside a design editor.

Example:

```text
1. Select Rectangle
2. Draw a wide horizontal card
3. Set W 520 / H 180 if fields are visible
4. Set radius 44 if visible
5. Set fill #151515
Good enough: a dark rounded card is on the canvas
```

There is also a bundled doc fallback based on OpenAI’s **Designing delightful frontends with GPT-5.4** guide:

```text
https://developers.openai.com/blog/designing-delightful-frontends-with-gpt-5-4
```

## What Shipped

### Pawscript Panel

Pawscript adds a compact workflow section to the Clicky menu bar panel:

- YouTube / Doc source tabs.
- URL input.
- **Extract skill** button.
- Customization prompt.
- Prerequisite checklist.
- **Guide me**, **Next**, **Stuck**, **Pause**, **Resume**, **Stop guide** controls.
- **Watch Spanks do it**, **Continue**, and **Stop Spanks** controls for agent runs.
- Show/hide tips toggle for the cat instruction bubble.
- Current step preview.
- `Substeps / reference` panel with deterministic values.
- Human completion, agent completion, and gotcha counters.
- Latest run-log affordance with an **Open** button.

### Guide Me

Guide mode is the reliable live demo path. Spanks:

- starts after the setup checkpoint when needed
- narrates the current step
- shows substeps and “good enough” criteria
- watches the screen and points at likely UI targets
- moves the overlay cursor and can move the system cursor to the detected target
- never clicks or types for the human in guide mode
- lets the user manually advance with **Next**
- lets the user intentionally save a gotcha with **Stuck**
- supports pause/resume/stop
- increments `humanCompletions` when the skill completes

This mode is intentionally calmer than full automation. It solves the actual demo problem: the user can keep moving even when the target app has login, account state, custom canvas state, or UI drift.

### Watch Spanks Do It

Agent mode is the Browser Use path for browser-safe workflows. It:

- launches a dedicated visible **Pawscript Chrome** profile
- connects Browser Use over Chrome DevTools Protocol
- uses the OpenAI key saved in Clicky settings
- streams JSONL status events back to Swift
- logs browser profile, control directory, process output, and run state
- pauses for login, setup, private data, billing, uploads, low-confidence states, and repeated page errors
- lets the user press **Continue** after fixing the visible browser state
- increments `agentCompletions` on success
- records Browser Use failures as gotchas

For the final Paper.design demo, **Guide me is the deterministic path**. Browser Use remains wired as the agent proof path, but Paper’s editor can be brittle enough that the stage-safe story is human + Spanks.

### Run Logs

Every extraction, guide run, and agent run can write a persistent local run log:

```text
~/Library/Application Support/Pawscript/runs/
```

Each run directory contains `run.json` with timeline events, mode, source URL, skill title, final state, counters, artifacts, Browser Use exit code, and error summary. Stuck events can save screenshots/context artifacts.

### Spanks Sprite States

The old simple cursor buddy is now backed by project-local pixel-cat sprite sheets:

```text
leanring-buddy/SpanksSpriteAssets/
```

The sprite state maps to app state:

- idle
- listening
- capturing screen
- thinking
- speaking
- pointing
- waiting for human
- success
- agent running
- error
- permission needed
- disabled

The SwiftUI fallback cat remains useful if image loading fails.

### OpenAI Settings

The Clicky panel now supports OpenAI configuration for local demo paths:

- save/clear OpenAI API key
- choose OpenAI text-to-speech model
- choose OpenAI voice
- customize OpenAI voice style instructions
- use OpenAI transcription as a listen backend
- use OpenAI for Pawscript extraction, screen matching, and Browser Use

The OpenAI key is stored in macOS Keychain, not in `UserDefaults`.

## Why This Matters

Pawscript is a human-facing execution layer for saved learning material.

Most saved tutorials fail because they are passive:

- You have to translate the video into actions yourself.
- The tutorial assumes hidden setup.
- You get stuck on one UI mismatch and abandon it.
- The useful “gotchas” are never captured.
- Agents fail silently on vague steps that humans could have clarified.

Pawscript makes the workflow operational:

- The source becomes a structured skill.
- The skill has prerequisites, steps, gotchas, criteria, and tool notes.
- A human can follow it with live guidance.
- An agent can attempt browser-safe execution from the same structure.
- Corrections and stuck points feed back into the same skill package.

The important architectural bet is that **humans and agents consume the same skill format**.

## Workflow Recorder Compatibility

Pawscript uses Workflow Recorder-compatible models in:

```text
leanring-buddy/Skill.swift
```

Core models:

- `Skill`
- `SkillStep`
- `SkillGotcha`
- `SkillAcceptanceCriterion`

Pawscript wraps those with demo/runtime metadata:

- `PawscriptSkillPackage`
- `PawscriptPrerequisite`
- `PawscriptScreenMatch`
- `PawscriptBrowserUseEvent`
- `PawscriptExecutionEvent`
- `PawscriptRunRecord`

This keeps the core contract close to Workflow Recorder while allowing Clicky-specific runtime behavior.

## Demo Script

Use this if you are rehearsing the hackathon submission.

1. Open the Xcode project.
2. Run the `leanring-buddy` scheme.
3. Grant Microphone, Accessibility, and Screen Recording permissions.
4. Open the Clicky menu bar panel.
5. In Pawscript, use the YouTube tab and paste:

   ```text
   https://www.youtube.com/watch?v=Ny3rvJWT5PM
   ```

6. Click **Extract skill**.
7. Show the Paper skill preview, prerequisites, substeps/reference panel, and counters.
8. Click **Guide me**.
9. If Paper login or canvas setup appears, complete it manually and click **I’m done - continue**.
10. Let Spanks point and narrate the first actionable step.
11. Complete one or two visible substeps.
12. Click **Stuck** once to show gotcha capture.
13. Click **Next** to advance and show that the tutorial is now a guided checklist.
14. Optionally click **Watch Spanks do it** to show the Browser Use path and human handoff controls.
15. Open the run log to show the execution trail.

The best stage line:

> “The video was passive. Now it is a session: steps, substeps, setup checkpoints, gotchas, and a human/agent execution path.”

## Requirements

### macOS App

- macOS 14.2 or newer
- Xcode 15 or newer
- Google Chrome for the Browser Use path
- Microphone permission
- Accessibility permission
- Screen Recording permission
- A signing team configured in Xcode

### OpenAI

For Pawscript’s live extraction, screen matching, OpenAI TTS, OpenAI transcription, and Browser Use:

- Add your OpenAI API key in the Clicky panel.
- Set Voice to `OpenAI` if you want OpenAI text-to-speech.
- Set Listen to `OpenAI` if you want OpenAI transcription.

### Browser Use

Pawscript does not auto-install demo tools. Install them before attempting **Watch Spanks do it**:

```bash
brew install yt-dlp
uv venv --python 3.12
source .venv/bin/activate
uv pip install browser-use openai python-dotenv
uvx browser-use install
```

If you use a custom Python environment, set `PAWSCRIPT_PYTHON` in your Xcode scheme or launch environment:

```bash
PAWSCRIPT_PYTHON=/path/to/python open leanring-buddy.xcodeproj
```

### Cloud AI Path

The original Clicky cloud path uses a Cloudflare Worker proxy for Claude, AssemblyAI, and ElevenLabs. The app does not ship those secrets.

Required Worker secrets:

- `ANTHROPIC_API_KEY`
- `ASSEMBLYAI_API_KEY`
- `ELEVENLABS_API_KEY`

Required Worker var:

- `ELEVENLABS_VOICE_ID`

## Build And Run

Open the project in Xcode:

```bash
open leanring-buddy.xcodeproj
```

In Xcode:

1. Select the `leanring-buddy` scheme.
2. Set your signing team.
3. Press Cmd+R.

Important: avoid terminal `xcodebuild` for normal local testing. It can invalidate or confuse macOS TCC permissions for Screen Recording, Accessibility, and Microphone access. macOS permissions are, regrettably, a tiny dungeon crawler.

Known non-blocking warning:

- `SpanksSpriteView.swift` currently emits a macOS 14 `onChange(of:perform:)` deprecation warning.

## Cloudflare Worker Setup

Install Worker dependencies:

```bash
cd worker
npm install
```

Add secrets:

```bash
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ASSEMBLYAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
```

Set the ElevenLabs voice ID in `worker/wrangler.toml`:

```toml
[vars]
ELEVENLABS_VOICE_ID = "your-voice-id-here"
```

Deploy:

```bash
npx wrangler deploy
```

For local Worker development:

```bash
cd worker
npx wrangler dev
```

Create `worker/.dev.vars`:

```text
ANTHROPIC_API_KEY=sk-ant-...
ASSEMBLYAI_API_KEY=...
ELEVENLABS_API_KEY=...
ELEVENLABS_VOICE_ID=...
```

Then point the Swift proxy URLs at the local Worker while developing.

## Architecture

Clicky is a SwiftUI macOS app with AppKit bridges where macOS requires them.

### App Shell

- `leanring_buddyApp.swift` starts the menu bar app.
- `MenuBarPanelManager.swift` owns the `NSStatusItem` and custom non-activating `NSPanel`.
- `CompanionPanelView.swift` renders the main control panel.
- `PawscriptPanelView.swift` renders the tutorial/session UI.
- `DesignSystem.swift` holds shared colors, radii, and visual tokens.

### Companion Runtime

- `CompanionManager.swift` is the central state machine.
- `BuddyDictationManager.swift` handles push-to-talk recording.
- `GlobalPushToTalkShortcutMonitor.swift` listens for the global modifier shortcut.
- `CompanionScreenCaptureUtility.swift` captures all screens.
- `ClaudeAPI.swift` streams Claude responses through the Worker.
- `ClaudeCLIAdapter.swift` runs local Claude Code CLI when selected.
- `CodexCLIAdapter.swift` supports local Codex CLI style execution.
- `ElevenLabsTTSClient.swift`, `OpenAITTSClient.swift`, and `LocalTTSClient.swift` handle voice output.
- `AssemblyAIStreamingTranscriptionProvider.swift`, `OpenAIAudioTranscriptionProvider.swift`, and `AppleSpeechTranscriptionProvider.swift` handle listen modes.
- `OverlayWindow.swift` renders the cursor, text bubble, waveform, subtitles, and Spanks overlay.
- `SpanksSpriteView.swift` renders pixel-cat animation states.

### Pawscript Runtime

- `PawscriptExecutionManager.swift` coordinates extraction, guide mode, Browser Use mode, handoff, gotcha capture, completion counters, and run state.
- `PawscriptSourceExtractor.swift` routes YouTube/doc sources to live extraction or bundled fallbacks.
- `PawscriptYouTubeCaptionExtractor.swift` extracts YouTube captions through `yt-dlp`.
- `PawscriptLLMSkillExtractor.swift` turns source text into a skill package with OpenAI.
- `PawscriptPromptBuilder.swift` builds Codex/agent-ready prompts from skill packages.
- `PawscriptURLResolver.swift` normalizes stale tutorial URLs and preflights navigable steps.
- `PawscriptScreenMatcher.swift` uses screenshots and OpenAI vision to find current-step targets.
- `PawscriptContextCapture.swift` saves stuck-state screenshots and context.
- `PawscriptRunLogger.swift` writes durable local run logs.
- `PawscriptBrowserUseExecutor.swift` launches the Python runner and streams Browser Use events back to Swift.
- `PawscriptScripts/pawscript_browser_agent.py` runs Browser Use against the visible Pawscript Chrome session.
- `PawscriptSkills/*.json` contains bundled demo/fallback skills.

### Worker Proxy

The Worker lives in `worker/src/index.ts` and exposes:

| Route | Upstream | Purpose |
| --- | --- | --- |
| `POST /chat` | Anthropic Messages API | Claude vision and streaming chat |
| `POST /tts` | ElevenLabs TTS | Voice audio |
| `POST /transcribe-token` | AssemblyAI streaming token API | Short-lived websocket token |

## Project Structure

```text
leanring-buddy/
  leanring_buddyApp.swift
  CompanionManager.swift
  CompanionPanelView.swift
  OverlayWindow.swift
  SpanksSpriteView.swift
  Skill.swift
  Pawscript*.swift
  PawscriptScripts/
    pawscript_browser_agent.py
  PawscriptSkills/
    paper-shaders-design-guide.json
    openai-delightful-frontends.json
    youtube-codex-tutorial.json
  SpanksSpriteAssets/
worker/
  src/index.ts
  wrangler.toml
wiki/
  INDEX.md
  topics/
  concepts/
AGENTS.md
CLAUDE.md
README.md
```

The project name keeps the legacy `leanring-buddy` typo. Do not rename it unless you also want to spend an afternoon negotiating with Xcode’s ghosts.

## Local Data

Pawscript stores generated and updated skill packages under:

```text
~/Library/Application Support/Pawscript/
```

Run logs are written under:

```text
~/Library/Application Support/Pawscript/runs/
```

Browser Use uses a dedicated Chrome profile under:

```text
~/Library/Application Support/Pawscript/browser-profile/
```

This keeps demo state separate from your normal Chrome profile.

## Safety Boundaries

Pawscript v1 is deliberately browser-first and human-handoff-first.

- It does not automate login or credentials.
- It does not purchase, submit private data, or change billing/account settings.
- It pauses when the workflow needs a human.
- It uses visible browser automation so the presenter can see and correct it.
- Guide mode points and explains; it does not click/type for the user.
- Agent mode is constrained to Browser Use for browser workflows.
- The skill contract stays backend-independent so another executor can be added later.

Full desktop computer-use systems such as CUA are a natural roadmap item, but Browser Use was the right demo-day backend because the shipped tutorials are browser workflows and the failure mode is visible on stage.

## Roadmap

- Add a `CUAExecutor` or equivalent desktop automation backend beside Browser Use.
- Save richer before/after screenshots for each step.
- Add shareable skill export/import.
- Add signed demo assets for image-upload tutorials.
- Add a gallery of verified tutorial-to-skill packages.
- Improve extraction quality scoring before a source becomes runnable.
- Add a safer dry-run mode that explains what the agent would do before it acts.
- Bridge Pawscript skill packages back into Workflow Recorder storage directly.

## Credits

This repo is a hackable Clicky fork with a Pawscript demo-day layer. The original Clicky concept is an AI buddy that lives on your Mac and helps by seeing, speaking, and pointing. Pawscript extends that idea from “answer my question” to “turn this saved tutorial into an active session.”

Original Clicky context:

- Website: [clicky.so](https://www.clicky.so/)
- Original tweet: [Farza on X](https://x.com/FarzaTV/status/2041314633978659092)

Demo-day components and inspiration:

- Workflow Recorder-compatible skill data model
- Browser Use for browser automation
- `yt-dlp` for YouTube captions
- OpenAI for extraction, vision matching, voice, transcription, and agent LLM use
- Paper.design as the hero browser/design workflow
- Spanks sprite sheets generated for the live companion states

## License

MIT, matching the original Clicky repo.
