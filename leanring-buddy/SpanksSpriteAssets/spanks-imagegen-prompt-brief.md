# Spanks Imagegen Prompt Brief

Use case: `stylized-concept`

Asset type: macOS overlay companion sprite sheets

Primary request: Generate transparent pixel-art sprite strips for the Spanks cat companion used in Pawscript guidance flows.

Subject: A tiny expressive cat companion that can live next to the system cursor, point at UI targets, listen, think, speak, wait for a human step, run agent workflows, celebrate success, recover from failure, ask for permissions, and sleep when disabled.

Style/medium: Crisp modern pixel art, transparent PNG, nearest-neighbor friendly, no antialiasing look. The cat should feel charming and readable at small sizes, not like a full game character portrait.

Composition/framing: One horizontal strip per animation. Each frame is intended for a 128 by 128 px cell. Keep the cat centered with a stable bottom-center anchor at x=64, y=108. Preserve the same foot baseline and body center across frames to prevent visual popping.

Color palette: Charcoal black cat body, cool blue highlights, white facial details. Keep it compatible with the existing blue cursor overlay.

Constraints: Transparent background; no text; no labels; no watermark; no border; no UI chrome; no baked drop shadow; no duplicate rows; no contact sheet labels; no props unless explicitly requested in the animation prompt.

Avoid: Photorealism, painterly soft edges, vector icon style, plush toy style, large mascot proportions, busy accessories, random UI elements, speech bubbles, arrows, lock icons, confetti, and letters.

## Generation Notes

The JSONL prompt pack is designed for `scripts/image_gen.py generate-batch` in the explicit CLI fallback path.

The generated image model may not perfectly respect exact sprite-strip geometry. After generation, each strip should be inspected and, if needed, trimmed or regenerated before wiring it into the runtime renderer.

