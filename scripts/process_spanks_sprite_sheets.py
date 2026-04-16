#!/usr/bin/env python3
"""Convert generated Spanks concept sheets into transparent sprite strips."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ASSET_DIRECTORY = Path("leanring-buddy/SpanksSpriteAssets")
RAW_DIRECTORY = Path("scripts/spanks-generated-raw")
MANIFEST_PATH = ASSET_DIRECTORY / "spanks-sprite-manifest.json"
PREVIEW_DIRECTORY = ASSET_DIRECTORY / "Preview"


def is_foreground_pixel(red: int, green: int, blue: int, alpha: int) -> bool:
    if alpha == 0:
        return False

    darkest_channel = min(red, green, blue)
    brightest_channel = max(red, green, blue)
    saturation = brightest_channel - darkest_channel
    brightness = (red + green + blue) / 3

    # The image model tends to place the cats on a gray studio canvas. Keep the
    # dark body pixels and colored facial accents, while dropping gray backdrop.
    if brightness < 76:
        return True
    if saturation > 36 and brightness < 170:
        return True
    return False


def foreground_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    rgba_image = image.convert("RGBA")
    width, height = rgba_image.size
    pixels = rgba_image.load()

    min_x = width
    min_y = height
    max_x = 0
    max_y = 0

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if is_foreground_pixel(red, green, blue, alpha):
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    if min_x > max_x or min_y > max_y:
        raise ValueError("No foreground pixels found")

    return min_x, min_y, max_x + 1, max_y + 1


def transparent_foreground_crop(image: Image.Image, bounds: tuple[int, int, int, int]) -> Image.Image:
    crop = image.convert("RGBA").crop(bounds)
    pixels = crop.load()
    width, height = crop.size

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if is_foreground_pixel(red, green, blue, alpha):
                pixels[x, y] = (red, green, blue, 255)
            else:
                pixels[x, y] = (red, green, blue, 0)

    return crop


def find_foreground_components(image: Image.Image) -> list[tuple[int, int, int, int, int]]:
    rgba_image = image.convert("RGBA")
    width, height = rgba_image.size
    pixels = rgba_image.load()
    visited: set[tuple[int, int]] = set()
    components: list[tuple[int, int, int, int, int]] = []

    for y in range(height):
        for x in range(width):
            if (x, y) in visited:
                continue

            red, green, blue, alpha = pixels[x, y]
            if not is_foreground_pixel(red, green, blue, alpha):
                visited.add((x, y))
                continue

            stack = [(x, y)]
            visited.add((x, y))
            min_x = x
            min_y = y
            max_x = x
            max_y = y
            area = 0

            while stack:
                current_x, current_y = stack.pop()
                area += 1
                min_x = min(min_x, current_x)
                min_y = min(min_y, current_y)
                max_x = max(max_x, current_x)
                max_y = max(max_y, current_y)

                for neighbor_x, neighbor_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if neighbor_x < 0 or neighbor_y < 0 or neighbor_x >= width or neighbor_y >= height:
                        continue
                    if (neighbor_x, neighbor_y) in visited:
                        continue
                    neighbor_red, neighbor_green, neighbor_blue, neighbor_alpha = pixels[neighbor_x, neighbor_y]
                    if is_foreground_pixel(neighbor_red, neighbor_green, neighbor_blue, neighbor_alpha):
                        visited.add((neighbor_x, neighbor_y))
                        stack.append((neighbor_x, neighbor_y))
                    else:
                        visited.add((neighbor_x, neighbor_y))

            component_width = max_x - min_x + 1
            component_height = max_y - min_y + 1
            if area > 40 and component_width > 6 and component_height > 6:
                components.append((min_x, min_y, max_x + 1, max_y + 1, area))

    return components


def select_frame_components(image: Image.Image, frame_count: int) -> list[tuple[int, int, int, int]]:
    components = find_foreground_components(image)
    components = sorted(components, key=lambda component: component[4], reverse=True)
    selected_components = components[:frame_count]
    selected_components = sorted(selected_components, key=lambda component: component[0])

    if len(selected_components) < frame_count:
        print(
            f"Warning: expected {frame_count} foreground components, found {len(selected_components)}. "
            "Duplicating the final detected frame."
        )
        while len(selected_components) < frame_count:
            selected_components.append(selected_components[-1])

    return [
        (min_x, min_y, max_x, max_y)
        for min_x, min_y, max_x, max_y, _area in selected_components
    ]


def fit_frame_to_canvas(frame: Image.Image, frame_width: int, frame_height: int, anchor_y: int) -> Image.Image:
    transparent_canvas = Image.new("RGBA", (frame_width, frame_height), (0, 0, 0, 0))
    frame.thumbnail((frame_width - 12, frame_height - 12), Image.Resampling.NEAREST)

    paste_x = (frame_width - frame.width) // 2
    paste_y = max(2, min(anchor_y - frame.height, frame_height - frame.height - 2))
    transparent_canvas.alpha_composite(frame, (paste_x, paste_y))
    return transparent_canvas


def process_animation(animation_key: str, animation: dict, frame_width: int, frame_height: int, anchor_y: int) -> None:
    raw_path = RAW_DIRECTORY / animation["file"]
    output_path = ASSET_DIRECTORY / animation["file"]
    if not raw_path.exists():
        raise FileNotFoundError(raw_path)

    raw_image = Image.open(raw_path).convert("RGBA")
    frame_count = int(animation["frames"])
    raw_width, raw_height = raw_image.size
    frame_bounds = select_frame_components(raw_image, frame_count)

    output_strip = Image.new("RGBA", (frame_width * frame_count, frame_height), (0, 0, 0, 0))

    for frame_index, bounds in enumerate(frame_bounds):
        bounds_with_padding = (
            max(0, bounds[0] - 8),
            max(0, bounds[1] - 8),
            min(raw_width, bounds[2] + 8),
            min(raw_height, bounds[3] + 8),
        )
        foreground_frame = transparent_foreground_crop(raw_image, bounds_with_padding)
        final_frame = fit_frame_to_canvas(foreground_frame, frame_width, frame_height, anchor_y)
        output_strip.alpha_composite(final_frame, (frame_index * frame_width, 0))

    output_strip.save(output_path)
    print(f"Wrote {output_path} from {raw_path} ({animation_key})")


def build_preview(animation_files: list[str], frame_width: int, frame_height: int) -> None:
    PREVIEW_DIRECTORY.mkdir(parents=True, exist_ok=True)
    preview_scale = 2
    preview_cell_width = frame_width * preview_scale
    preview_cell_height = frame_height * preview_scale
    columns = 4
    rows = (len(animation_files) + columns - 1) // columns
    preview = Image.new("RGBA", (columns * preview_cell_width, rows * preview_cell_height), (24, 24, 24, 255))

    for index, animation_file in enumerate(animation_files):
        strip = Image.open(ASSET_DIRECTORY / animation_file).convert("RGBA")
        first_frame = strip.crop((0, 0, frame_width, frame_height))
        first_frame = first_frame.resize((preview_cell_width, preview_cell_height), Image.Resampling.NEAREST)
        x = (index % columns) * preview_cell_width
        y = (index // columns) * preview_cell_height
        preview.alpha_composite(first_frame, (x, y))

    preview_path = PREVIEW_DIRECTORY / "spanks-first-frame-preview.png"
    preview.save(preview_path)
    print(f"Wrote {preview_path}")


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    frame_width = int(manifest["frameWidth"])
    frame_height = int(manifest["frameHeight"])
    anchor_y = int(manifest["anchorY"])

    animation_files: list[str] = []
    for animation_key, animation in manifest["animations"].items():
        process_animation(animation_key, animation, frame_width, frame_height, anchor_y)
        animation_files.append(animation["file"])

    build_preview(animation_files, frame_width, frame_height)


if __name__ == "__main__":
    main()
