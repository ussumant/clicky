# Accessible operator workflow: Paper Shaders

Source video: https://www.youtube.com/watch?v=Q_bd7BFh0XY  
Purpose: help a blind user create a Paper Shader graphic with a sighted or AI-assisted operator.

This workflow is written for an operator who has never used Paper before. You do not need to know the tool in advance. Your job is to read the screen, find controls that match the intent, and report visual feedback clearly.

## Roles

**Blind user**

- Chooses the design goal.
- Decides whether the output should be subtle, bold, animated, static, code, image, or SVG.
- Approves each major visual direction based on the operator's description.

**Operator**

- Navigates Paper.
- Finds likely controls even when labels differ.
- Describes the visual state in plain language.
- Anticipates when the interface has changed and adapts without getting stuck.

## Before starting

Ask the blind user these questions:

1. What are we making?
   Examples: poster background, launch graphic, web hero, social card, abstract texture.

2. Should it move?
   Choose one: static, subtle motion, animated hero.

3. Should the final output be code or a design asset?
   Choose one: React code, static image/texture, SVG, not sure yet.

4. Do you already have an image to use?
   Choose one: upload an image, generate one in Paper, use an existing canvas image, start with pure shader patterns.

Use the answers as the design brief.

## Operator description rules

When describing the screen, avoid vague taste words like "cool" or "nice" by themselves. Use this structure:

```text
I see [main subject or pattern].
The effect is [subtle / balanced / intense / chaotic].
The dominant shapes are [lines / waves / dots / glass ridges / soft blobs / paper texture].
The dominant colors are [name 2-4 colors].
This would work best as [background / poster / hero / texture / icon-like SVG].
The main risk is [too busy / too subtle / text would be unreadable / source image is lost].
```

## Step 1: Open Paper or Paper Shaders

Concrete action:

1. Open https://paper.design/.
2. Look for a way to open a canvas, demo, editor, playground, or shader library.
3. If asked to sign in, pause and ask the blind user whether to continue.

Abstract intent:

Get to an editable screen where a shader can be placed or customized. The exact starting page may differ.

What to tell the blind user:

```text
I am on [landing page / shader library / editor / canvas].
I see controls for [presets / parameters / export / image input] or I do not see them yet.
```

If stuck:

- Search the page for words like `Shaders`, `Canvas`, `Editor`, `Open`, `Try`, `Templates`, or `Library`.
- If you only see a marketing page, use the Paper Shaders link directly.
- If no editor appears, describe the available buttons and ask which one to try.

Success check:

You can see either a shader preview or a design canvas with effect controls.

## Step 2: Add or select a shader

Concrete action:

1. Find a shader already on the canvas, or open the shader library.
2. Select a shader similar to `Warp` if available.
3. If `Warp` is not visible, choose any shader that creates abstract patterns, waves, lines, or distortion.

Abstract intent:

Start with a generated shader effect, not an uploaded image filter yet.

What to tell the blind user:

```text
I selected a shader named [name].
It currently looks like [describe pattern].
I can see [presets / sliders / numeric controls / speed / export].
```

If stuck:

- If the canvas has objects, click the object that looks animated or abstract.
- If there is a left sidebar, look there for shader names.
- If there is a right sidebar, look there for settings after selecting the object.
- If the selected thing is an image rather than a shader, continue only if shader controls appear.

Success check:

A shader is selected and its settings are visible.

## Step 3: Choose a preset

Concrete action:

1. Look for a preset dropdown, preset list, thumbnails, or named styles.
2. Try 3 to 5 presets.
3. After each preset, describe the change.

Abstract intent:

Use presets as starting points. Do not try to invent the look from blank controls.

Preset description template:

```text
Preset [name or number] creates [lines / blobs / ripples / glass / dots].
It feels [subtle / balanced / strong / too chaotic].
It would work for [background / poster / animation / texture].
```

Ask the blind user:

```text
Do you want the safer subtle direction, the bolder poster direction, or should I keep exploring?
```

If stuck:

- If there is no preset label, use thumbnail order: first preset, second preset, third preset.
- If clicking a preset does nothing, ensure the shader object is selected.
- If the page is slow, wait a few seconds before judging.

Success check:

The blind user chooses a direction to refine.

## Step 4: Tune the shader

Concrete action:

1. Find the visible parameter controls.
2. Change one control at a time.
3. After each meaningful change, describe what changed.
4. Stop when the effect supports the user's design goal.

Common controls and what they usually mean:

- `Speed`: controls motion. Set to `0` for a static texture.
- `Scale` or `Size`: makes the pattern larger or smaller.
- `Intensity`, `Amount`, or `Strength`: makes the effect more or less dramatic.
- `Distortion` or `Warp`: bends the pattern more.
- `Frequency`, `Lines`, or `Density`: changes how many repeated marks appear.
- `Color`: changes the palette.

Abstract intent:

Make the shader feel designed rather than like an untouched preset.

What to tell the blind user:

```text
I changed [control] from [old rough value] to [new rough value].
The effect is now [description].
The risk is now [none / too busy / too faint / motion too distracting].
```

If stuck:

- If you cannot understand a control, move it slightly and describe the visual effect.
- If the design becomes chaotic, undo or move the control halfway back.
- If the effect is barely visible, increase strength, contrast, or scale.
- If it distracts from text or a subject, reduce strength or density.

Success check:

The blind user approves the shader direction.

## Step 5: Decide static or animated

Concrete action:

1. If the user wants static output, set `Speed` to `0`.
2. If the user wants animation, keep speed on but reduce it if the motion is distracting.
3. Watch for 5 seconds and describe the motion.

Abstract intent:

Motion should be a deliberate output choice, not an accidental default.

What to tell the blind user:

```text
The motion is [none / slow / medium / fast].
It feels [calm / energetic / distracting].
For your goal, I recommend [static / subtle motion / animated].
```

If stuck:

- If there is no speed control, look for animation, time, movement, play, or motion controls.
- If motion cannot be disabled, consider exporting a still image instead of code.

Success check:

The user confirms whether the shader should move.

## Step 6: Export the shader if code is needed

Concrete action:

1. Look for `Export`, `Copy`, `Code`, `React`, or `Copy as React`.
2. Choose `Copy as React` if available.
3. Paste it into a scratch text area or code editor only if the user wants to inspect or save it.

Abstract intent:

Capture the exact shader configuration as reusable code.

What to tell the blind user:

```text
I found [export option].
The available formats are [list formats].
I copied [React code / another format].
```

If stuck:

- If `Copy as React` is not visible, open menus near export/share/code icons.
- If export is disabled, the shader may need to be selected first.
- If code is not needed, skip this step.

Success check:

The shader output is copied or the user confirms no code export is needed.

## Step 7: Add an image filter shader

Concrete action:

1. Add or select an image filter shader.
2. Use `Fluted Glass` if available.
3. If not, choose a shader that takes an image input, such as glass, paper, water, halftone, blur, or distortion.

Abstract intent:

Now transform an image instead of generating only an abstract pattern.

What to tell the blind user:

```text
I selected an image filter named [name].
It needs an image source, or it already has one.
```

If stuck:

- Look for controls named `Image`, `Input`, `Source`, `Upload`, `Edit`, or an eyedropper icon.
- If the shader does not accept an image, choose another shader.

Success check:

An image filter is selected and ready for an image source.

## Step 8: Provide an image source

Choose one path.

Path A: upload an image

1. Click `Edit`, `Upload`, `Choose file`, or similar.
2. Select the user's image.
3. Wait until it appears in the shader.

Path B: use an image already on the canvas

1. Choose the eyedropper or picker tool.
2. Click the image on the canvas that should feed the shader.

Path C: generate an image

1. Find image generation in Paper.
2. Use a prompt based on the user's goal.
3. Pick the strongest generated option.
4. Feed that image into the shader.

Example prompt:

```text
A beautiful sunset over a lake, retro poster style, bold shapes, clean color blocks
```

Abstract intent:

Give the image filter strong source material with clear colors and shapes.

What to tell the blind user:

```text
The source image contains [subject].
The shader transforms it by [glass ridges / waves / dots / texture].
The subject is [clear / partly abstracted / mostly lost].
```

If stuck:

- If upload fails, try drag and drop.
- If the eyedropper picks the wrong thing, undo and click closer to the center of the image.
- If generated images are too detailed, ask for flatter shapes and fewer details.

Success check:

The image is visibly transformed by the shader.

## Step 9: Try image filter presets

Concrete action:

1. With the image filter selected, try 3 to 5 presets.
2. Describe each preset using the same template.
3. Ask the blind user to choose a direction.

Abstract intent:

Find the best transformation for the image before fine-tuning.

Useful descriptions:

- Glass or fluted glass: image appears seen through ribbed or warped glass.
- Waves or folds: image bends in flowing bands.
- Halftone: image becomes dots or print texture.
- Paper: image gains fiber, grain, or handmade texture.
- Water: image ripples or refracts.

If stuck:

- If the preset does not visibly change the image, check that the image filter is selected.
- If every preset destroys the subject, reduce strength or use a simpler image.

Success check:

The user chooses one image treatment.

## Step 10: Tune image filter strength

Concrete action:

1. Adjust strength, amount, distortion, density, or similar controls.
2. Aim for one of three levels:
   - subtle background
   - balanced graphic
   - bold poster
3. Describe which level the current result matches.

Abstract intent:

Control how much the shader transforms the image.

What to tell the blind user:

```text
The effect is now [subtle / balanced / bold].
The original image is [clear / partially recognizable / mostly abstract].
For [user goal], I recommend [current level or adjustment].
```

If stuck:

- For text-heavy layouts, make the effect more subtle.
- For posters or abstract graphics, stronger effects can work.
- If the image becomes muddy, reduce density or distortion.

Success check:

The image filter has an intentional strength level.

## Step 11: Chain a second shader

Concrete action:

1. Add a second shader effect on top of the first result.
2. Try `Halftone` if available, especially a vintage or retro preset.
3. Describe whether the combination improves or worsens the result.

Abstract intent:

Layer effects only when the second effect adds a clear visual idea.

What to tell the blind user:

```text
The first effect is [describe].
The second effect adds [dots / grain / waves / texture].
Together they feel [better / too busy / more poster-like / less readable].
```

If stuck:

- If you cannot layer effects directly, duplicate or use the already-filtered image as the next shader's input.
- If the result is too noisy, reduce the second shader's strength.
- If still too noisy, remove the second shader and keep the better single effect.

Success check:

The user either approves the chain or chooses to return to a single shader.

## Step 12: Vectorize a flat image if useful

Concrete action:

1. Select a flat image or generated illustration.
2. Right-click it.
3. Choose `Vectorize` if available.
4. Wait for the SVG result.
5. Scale it up and check whether it stays sharp.

Abstract intent:

Convert a flat bitmap into a scalable SVG when the final asset needs crisp resizing.

What to tell the blind user:

```text
The source image is [flat enough / too detailed] for vectorizing.
After vectorizing, the result has [clean shapes / rough edges / lost details].
When scaled up, it [stays sharp / shows problems].
```

If stuck:

- If `Vectorize` is missing, check right-click menus, object menus, or command search.
- If the result looks bad, the image is probably too detailed. Use a flatter image.
- Do not vectorize photos unless the user wants a simplified graphic look.

Success check:

The SVG is clean enough, or the user decides not to vectorize.

## Step 13: Choose the final output

Ask the blind user to pick the final format:

```text
Do you want this as:
1. a live animated shader,
2. React code,
3. a static design texture,
4. an SVG,
5. or should we keep it inside the Paper file?
```

Recommend based on the work:

- Live animated shader: best for web heroes or interactive pages.
- React code: best for shipping the shader in a web app.
- Static texture: best for posters, social graphics, or backgrounds.
- SVG: best for flat graphics that must scale sharply.
- Paper file: best if the user wants to keep iterating.

Success check:

The output format matches the user's original goal.

## Final operator report

End with this summary:

```text
We made [type of graphic].
The final effect uses [shader names].
The image source is [uploaded / generated / canvas image / none].
The style is [subtle / balanced / bold / animated / static].
The output format is [React / static / SVG / Paper file].
The main visual risk is [risk or none].
My recommendation is [ship / tune more / simplify / ask for another visual check].
```

## Recovery guide

If the interface does not match these steps:

- Identify the current screen first: landing page, canvas, library, settings, export, or account page.
- Look for synonyms: shader may appear as effect, filter, visual, generator, material, or component.
- Search menus for the action: preset, upload, edit, image, export, code, React, vectorize.
- Change only one thing at a time so the blind user can understand cause and effect.
- When uncertain, describe what is visible and ask for a decision instead of guessing silently.

If the design gets visually worse:

- Undo once.
- Return to the last approved preset.
- Lower strength or density.
- Remove chained effects.
- Use a simpler image.
- Set speed to `0` if motion is distracting.

If the blind user cannot make a visual decision from the description:

- Offer two or three labeled options instead of unlimited choices.
- Example: "Option A is calm and subtle, Option B is bolder and poster-like, Option C is chaotic but energetic."
- Ask which option better matches the original goal.
