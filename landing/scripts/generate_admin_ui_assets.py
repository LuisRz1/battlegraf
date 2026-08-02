"""Build crisp, repeatable pixel-art UI assets for the BattleGraph admin console."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps


def build_seamless_stone(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGB")
    edge = min(image.size)
    left = (image.width - edge) // 2
    top = (image.height - edge) // 2
    crop = image.crop((left, top, left + edge, top + edge))
    crop = crop.resize((128, 128), Image.Resampling.NEAREST)

    tile = Image.new("RGB", (256, 256))
    tile.paste(crop, (0, 0))
    tile.paste(ImageOps.mirror(crop), (128, 0))
    tile.paste(ImageOps.flip(crop), (0, 128))
    tile.paste(ImageOps.mirror(ImageOps.flip(crop)), (128, 128))
    tile.save(destination, "WEBP", quality=82, method=6)


def build_clean_frame(destination: Path) -> None:
    size = 96
    inset = 18
    frame = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)

    # Flat pixel layers: no antialiasing means the 9-slice stays crisp at any size.
    draw.rectangle((0, 0, size - 1, size - 1), fill="#080908")
    draw.rectangle((2, 2, size - 3, size - 3), outline="#b07b32", width=2)
    draw.rectangle((5, 5, size - 6, size - 6), outline="#4d4940", width=4)
    draw.rectangle((9, 9, size - 10, size - 10), outline="#252621", width=5)
    draw.rectangle((inset, inset, size - inset - 1, size - inset - 1), fill=(0, 0, 0, 0))

    stone_dark = "#272824"
    stone_mid = "#484842"
    stone_light = "#68645a"
    mortar = "#111310"
    bronze = "#d09a42"
    crimson = "#8d2e32"

    # Repeatable masonry on horizontal edges.
    for x in range(inset, size - inset, 12):
        x2 = min(x + 10, size - inset - 1)
        draw.rectangle((x, 7, x2, 15), fill=stone_dark, outline=mortar)
        draw.line((x + 1, 8, x2 - 1, 8), fill=stone_light)
        draw.rectangle((x, size - 16, x2, size - 8), fill=stone_dark, outline=mortar)
        draw.line((x + 1, size - 15, x2 - 1, size - 15), fill=stone_mid)

    # Repeatable masonry on vertical edges.
    for y in range(inset, size - inset, 12):
        y2 = min(y + 10, size - inset - 1)
        draw.rectangle((7, y, 15, y2), fill=stone_dark, outline=mortar)
        draw.line((8, y + 1, 8, y2 - 1), fill=stone_light)
        draw.rectangle((size - 16, y, size - 8, y2), fill=stone_dark, outline=mortar)
        draw.line((size - 15, y + 1, size - 15, y2 - 1), fill=stone_mid)

    # Strong square corners and restrained team-red/gold heraldic accents.
    for x, y in ((4, 4), (size - 18, 4), (4, size - 18), (size - 18, size - 18)):
        draw.rectangle((x, y, x + 13, y + 13), fill="#171815", outline="#746c5d", width=2)
        draw.rectangle((x + 4, y + 4, x + 9, y + 9), fill=crimson)
        draw.point((x + 6, y + 5), fill=bronze)
        draw.point((x + 7, y + 5), fill=bronze)

    frame.save(destination, "PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    build_seamless_stone(args.source, args.output / "stone_tile.webp")
    build_clean_frame(args.output / "panel_frame_clean.png")


if __name__ == "__main__":
    main()
