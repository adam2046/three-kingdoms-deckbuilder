"""Pixel art converter — Floyd-Steinberg dithering with preset or named palette."""

from PIL import Image, ImageEnhance, ImageOps

try:
    from .palettes import PALETTES, build_palette_image
except ImportError:
    from palettes import PALETTES, build_palette_image


PRESETS = {
    "arcade": {
        "contrast": 1.8, "color": 1.5, "sharpness": 1.2,
        "posterize_bits": 5, "block": 8, "palette": 16,
    },
    "snes": {
        "contrast": 1.6, "color": 1.4, "sharpness": 1.2,
        "posterize_bits": 6, "block": 4, "palette": 32,
    },
    "nes": {
        "contrast": 1.5, "color": 1.4, "sharpness": 1.2,
        "posterize_bits": 6, "block": 8, "palette": "NES",
    },
    "pico8": {
        "contrast": 1.6, "color": 1.3, "sharpness": 1.2,
        "posterize_bits": 6, "block": 6, "palette": "PICO_8",
    },
}


def pixel_art(input_path, output_path, preset="arcade", **overrides):
    if preset not in PRESETS:
        raise ValueError(f"Unknown preset {preset!r}. Choose from: {sorted(PRESETS)}")
    cfg = {**PRESETS[preset], **overrides}

    img = Image.open(input_path).convert("RGB")

    img = ImageEnhance.Contrast(img).enhance(cfg["contrast"])
    img = ImageEnhance.Color(img).enhance(cfg["color"])
    img = ImageEnhance.Sharpness(img).enhance(cfg["sharpness"])
    img = ImageOps.posterize(img, cfg["posterize_bits"])

    w, h = img.size
    block = cfg["block"]
    small = img.resize(
        (max(1, w // block), max(1, h // block)),
        Image.Resampling.NEAREST if hasattr(Image, 'Resampling') else Image.NEAREST,
    )

    pal = cfg["palette"]
    if isinstance(pal, str):
        pal_img = build_palette_image(pal)
        quantized = small.quantize(palette=pal_img, dither=Image.Dither.FLOYDSTEINBERG if hasattr(Image, 'Dither') else Image.FLOYDSTEINBERG)
    else:
        quantized = small.quantize(colors=int(pal), dither=Image.Dither.FLOYDSTEINBERG if hasattr(Image, 'Dither') else Image.FLOYDSTEINBERG)

    result = quantized.resize((w, h), Image.Resampling.NEAREST if hasattr(Image, 'Resampling') else Image.NEAREST)
    result.save(output_path, "PNG")
    return result


if __name__ == "__main__":
    import sys
    import urllib.request

    # Download source image
    source_url = "https://fu2.sdo.com/23/123/1107/22/29/9856_10100029.PNG"
    source_path = "/Users/thomasyau/Projects/game1-three-kingdoms/assets/cards/caocao_source.png"
    output_path = "/Users/thomasyau/Projects/game1-three-kingdoms/assets/cards/caocao_portrait_snes.png"

    print(f"Downloading: {source_url}")
    urllib.request.urlretrieve(source_url, source_path)

    img = Image.open(source_path)
    print(f"Source: {img.size}")

    # Crop to portrait area (the reference card's portrait is ~ center-top)
    # Original looks like ~ 2:3 card, portrait is about 60% of the height
    w, h = img.size
    
    # The source is a full card. Let's extract just the portrait region.
    # From vision analysis: portrait area is center, let's estimate the crop
    # Looking at the reference: portrait is roughly from y=15% to y=60% of card height
    # And x from 15% to 85% of width
    
    portrait_x1 = int(w * 0.18)
    portrait_y1 = int(h * 0.12)
    portrait_x2 = int(w * 0.88)
    portrait_y2 = int(h * 0.58)
    
    portrait = img.crop((portrait_x1, portrait_y1, portrait_x2, portrait_y2))
    portrait_source = source_path.replace(".png", "_portrait.png")
    portrait.save(portrait_source, "PNG")
    print(f"Cropped portrait: {portrait.size} -> {portrait_source}")

    # Convert to SNES-style pixel art
    print("Converting to SNES pixel art...")
    pixel_art(portrait_source, output_path, preset="snes")
    print(f"Done: {output_path}")
    
    # Also make a smaller version for the card (330x286 pixels to match template)
    final = Image.open(output_path)
    resample = Image.Resampling.NEAREST if hasattr(Image, 'Resampling') else Image.NEAREST
    card_size = final.resize((330, 286), resample)
    card_output = output_path.replace(".png", "_card.png")
    card_size.save(card_output, "PNG")
    print(f"Card-sized version: {card_output}")
