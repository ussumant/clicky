# How to use Paper Shaders to elevate your designs

Source video: https://www.youtube.com/watch?v=Q_bd7BFh0XY  
Tool: Paper at https://paper.design, with shader effects inside an editable Paper canvas

## Goal

Use Paper Shaders to create distinctive visual treatments quickly, then reuse the result in a design, an animation, or production code.

By the end, you should be able to:

- Start from a shader preset instead of a blank effect.
- Customize shader parameters until the effect matches your design.
- Freeze an animated shader into a static texture.
- Pull an image into a shader with upload or the eyedropper.
- Chain shaders together for richer looks.
- Export the shader as React code.
- Vectorize a generated image into an SVG when the image is flat enough.

## What you need

- Paper: https://paper.design
- Paper Shaders: available from inside Paper's editor/shader controls
- A Paper canvas or design file.
- Optional: an image to filter. You can also generate one inside Paper.

## 1. Open a Paper canvas

Open Paper and start from a canvas where you can place shader elements.

In the video, the walkthrough begins with a shader already on the canvas: the Warp shader. You can follow the same pattern with any shader from the library.

Check: you should see a live shader object on the canvas and a settings panel with presets and parameters.

## 2. Pick a shader preset

Open the shader's preset list and click through a few options.

Presets are quick starts. They show the range of what a shader can do without forcing you to tune every value from scratch. As you switch presets, watch the parameter controls change. The preset is not the final design; it is a starting point.

For the Warp shader, the video shows presets that range from tight line-based looks to soft abstract shapes.

Check: the visual changes immediately when you choose a preset, and the parameter values update with it.

## 3. Tune the parameters

After choosing a preset, adjust the visible parameters until the shader matches the design direction.

Use this pass to make the effect feel intentional:

- Zoom in if the details are too small to judge.
- Adjust shape, distortion, scale, spacing, or intensity controls.
- Push the settings until the image becomes interesting, then pull back if it feels too noisy.
- Keep checking the shader at the size it will appear in the final design.

Check: the shader no longer looks like a stock preset; it has a customized look that fits your layout.

## 4. Make an animated shader static when needed

If the shader is animated but you want a still texture, set its speed to `0`.

This gives you a static graphic while preserving the shader's generated look. Keep speed above zero when the final output should move, such as an animated hero, social post, or launch asset.

Check: the shader stops moving but keeps the same visual style.

## 5. Export the shader as React

When the shader looks right, use the shader export option and choose `Copy as React`.

Paste the copied code into your project or into a scratch area to inspect it. The exported code reflects the exact shader configuration you dialed in on the canvas.

Check: the pasted React code represents the same live shader you customized in Paper.

## 6. Use an image filter shader

Next, try a shader that takes an image as input. The video uses Fluted Glass.

Add the image filter shader to the canvas, then provide an image source. You can:

- Click `Edit` to upload an image from your computer.
- Use the eyedropper tool to capture an image already visible on the canvas.
- Generate an image in Paper, then pull that image into the shader.

In the video, the prompt used for image generation is a retro-style sunset over a lake. Paper generates multiple options, then one generated image is pulled into the Fluted Glass shader.

Check: the shader uses your selected image as its source, and the image is visibly transformed by the effect.

## 7. Try filter presets on the image

With the image loaded into the shader, switch between filter presets.

For Fluted Glass, the video tries options like waves and folds. Use presets to find a direction quickly, then tune the parameters afterward.

Check: each preset changes how the image is distorted or refracted.

## 8. Control the strength of the effect

Adjust the shader parameters to decide how bold or subtle the image treatment should be.

For poster-style designs, a strong filter can become the main graphic. For product UI, editorial layouts, or background textures, a softer treatment may work better.

Check: the source image is still recognizable if you need it to be, and the filter strength fits the composition.

## 9. Chain multiple shaders

Apply another shader on top of the first shader to create a more complex result.

The video demonstrates adding a Halftone shader over the Fluted Glass result, using a vintage-style preset. This creates a layered look: the original generated image is first transformed by glass, then stylized with a retro halftone treatment.

Good combinations to try:

- Glass plus Halftone for retro posters.
- Paper plus Water for organic texture.
- Subtle Glass plus a low-intensity Halftone for editorial backgrounds.

Check: the second shader is applied on top of the first result, and the combined effect still supports the design instead of overwhelming it.

## 10. Return to the original image when needed

If the chained result gets too heavy, go back to the original image and apply only the shader you need.

The video returns to a cleaner source image and applies a vintage halftone look directly. This is useful when the combined shader stack is visually interesting but too intense for the final asset.

Check: the design has a clear visual idea without unnecessary layers.

## 11. Vectorize a flat image

For a flat image or illustration, right-click the image and choose `Vectorize`.

Paper uses AI to convert the image into an SVG. This works best when the source image is already relatively flat, graphic, and low-detail. After vectorizing, scale the result up to confirm it stays sharp.

Check: the converted image is an SVG and does not lose quality when scaled.

## 12. Decide what to ship

Choose the final output based on how you plan to use the graphic:

- Use the live shader if you want animation or interactive visuals.
- Use `Copy as React` if the shader should run in a web app.
- Use a static shader texture if you need a still design asset.
- Use `Vectorize` if the output should be resolution-independent SVG.

## Common gotchas

- Do not stop at the first preset. Presets are starting points.
- If an animated shader feels distracting, set speed to `0`.
- If an image filter looks too loud, reduce the effect strength before abandoning it.
- If chained shaders look messy, remove one layer and reapply the strongest idea directly to the source image.
- Vectorize flat images, not detailed photos, if you want clean SVG results.

## Quick checklist

- The shader starts from a preset.
- The parameters have been customized.
- Motion is intentional or speed is set to `0`.
- Image filters use a deliberate source image.
- Any chained shaders improve the design.
- Exported React code matches the canvas result.
- Vectorized assets stay sharp when scaled.

## Pawscript prompt

Use this prompt when turning the tutorial into a guided run:

```text
Guide me through creating a Paper Shaders design from the video "How to use Paper Shaders to elevate your designs."

Start in Paper, choose a shader preset, tune its parameters, decide whether the shader should animate or freeze, then export it as React. After that, guide me through adding an image filter shader, pulling in an image by upload, eyedropper, or image generation, trying presets, tuning effect strength, chaining a second shader, and vectorizing a flat image if appropriate.

Pause after each major step and ask me to confirm what I see before continuing. Call out gotchas around overusing presets, overly strong filters, distracting motion, messy shader chains, and vectorizing images that are too detailed.
```

## Browser Use agent mode

For a Browser Use agent, make the guide more strict than the human tutorial:

- Start at `https://paper.design/`, but continue only once an editable Paper canvas or shader editor is visible.
- If Paper shows login, signup, pricing, account setup, or project selection, pause and ask the user to complete that step.
- Use visible labels whenever possible: `Warp`, `Presets`, `Speed`, `Copy as React`, `Fluted Glass`, `Edit`, `Halftone`, `Vintage`, and `Vectorize`.
- Move quickly through obvious controls, but hand off when confidence is low.
- Treat image upload, eyedropper capture, export menus, and right-click context menus as likely handoff points.
- After each material canvas change, verify what changed before continuing.

Use this Browser Use prompt:

```text
Open https://paper.design/ and help me recreate the Paper Shaders workflow from the video.

Move fast through obvious UI states. If you see a clear editable Paper canvas or shader editor, continue. If you see login, signup, pricing, account setup, project selection, or a static gallery with no editable canvas, stop and ask me to open the right canvas manually.

Use visible labels and screen evidence. Look for Warp, Presets, Speed, Copy as React, Fluted Glass, Edit, eyedropper, Halftone, Vintage, and Vectorize. If your confidence is below 0.75 for any click or drag, ask me to click the correct target, then resume from the updated screen.

Do these steps:
1. Open or select a Warp shader.
2. Choose a preset and adjust one or two obvious parameters.
3. Set Speed to 0 if I want a static texture, or keep animation if I want motion.
4. Copy as React if the export control is visible; skip with a note if it is hidden.
5. Add or select Fluted Glass.
6. Pull in an image by upload, eyedropper, or image generation. Hand off if the image source is ambiguous.
7. Try a Halftone or Vintage shader layer only if the result is not already too busy.
8. If Vectorize is visible for a flat image, run it; otherwise skip.
9. Ask me to confirm the final output format: live shader, static texture, React code, or SVG.
```
