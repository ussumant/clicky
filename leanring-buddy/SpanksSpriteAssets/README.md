# Spanks Sprite Assets

Project-bound sprite assets for the Pawscript cat companion.

The app currently renders Spanks with SwiftUI shapes in `SpanksSpriteView.swift`. These generated PNG strips are the production asset target for replacing that renderer once the sheets exist.

## Required Format

- Transparent PNG sprite strips
- One horizontal strip per animation
- `128 x 128 px` per frame
- Consistent bottom-center anchor at `x=64`, `y=108`
- Cat body should occupy roughly `80 x 90 px` inside each frame
- Keep `12-20 px` transparent padding for ears, tail, paw motion, and bounce
- No baked drop shadow
- No text, labels, watermark, border, background, or UI chrome
- Pixel-art edges suitable for nearest-neighbor scaling

## Runtime Sizes

- Normal overlay: `64 x 64 pt`
- Speaking or emphasized: `72-80 pt`
- Pointing target: `56-72 pt`
- Panel preview: `40-48 pt`

## Expected Files

The manifest in `spanks-sprite-manifest.json` is the source of truth for file names, frame counts, frame rate, looping, and fallback behavior.

Generated finals should be saved in this directory:

- `spanks-idle.png`
- `spanks-listening.png`
- `spanks-capturing-screen.png`
- `spanks-thinking.png`
- `spanks-speaking.png`
- `spanks-pointing.png`
- `spanks-waiting-for-human.png`
- `spanks-success.png`
- `spanks-agent-running.png`
- `spanks-error.png`
- `spanks-permission-needed.png`
- `spanks-disabled.png`

## Generation Workflow

Keep generated source images outside the app target at `scripts/spanks-generated-raw/`.
Xcode's synchronized app group flattens copied resources, so keeping raw PNGs under
`leanring-buddy/SpanksSpriteAssets/GeneratedRaw/` would collide with the app-ready
sprite strips during build.

The app-ready strips live in this directory and are normalized by:

```bash
uv run python scripts/process_spanks_sprite_sheets.py
```

The processor:

- detects foreground cat poses from raw imagegen sheets
- removes the gray generated background
- fits each pose into transparent `128 x 128 px` frames
- writes the strip dimensions declared in `spanks-sprite-manifest.json`
- writes `Preview/spanks-first-frame-preview.png` for quick visual QA

The imagegen prompt pack is `spanks-imagegen-prompts.jsonl`.
