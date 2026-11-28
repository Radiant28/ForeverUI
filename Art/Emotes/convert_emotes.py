"""Converts the generated emote medallion PNGs (magenta background) into 64x64 32-bit TGA files for ChatEmotes.lua.

usage: python -I Art/Emotes/convert_emotes.py Art/Emotes <preview dir>  (needs Pillow; run from the addon root)
source/emote-<key>.png -> Emote-<key>.tga; the medallion is centred and scaled to FILL of the side, so turning it up
to 20 degrees in texture coordinates samples only the transparent margin.
"""
import sys, os
from PIL import Image

KEYS = ["laugh", "smile", "dance", "cry", "angry", "kiss", "love", "wave", "bow", "applaud", "cheer", "sleep",
        "surprised", "thank", "sad", "burp"]
SIDE, FILL = 64, 0.84

src_dir = os.path.join(sys.argv[1], "source")
out_dir = sys.argv[1]
preview_dir = sys.argv[2]


def key_magenta(im):
    """RGB with a #FF00FF background -> RGBA, antialiased edges unmixed from magenta."""
    im = im.convert("RGB")
    out = Image.new("RGBA", im.size)
    src, dst = im.load(), out.load()
    w, h = im.size
    clamp = lambda v: int(max(0, min(255, round(v))))
    for y in range(h):
        for x in range(w):
            r, g, b = src[x, y]
            m = min(r, b) - g
            if m < 40:
                dst[x, y] = (r, g, b, 255)
                continue
            a = 1 - (m - 40) / 190.0
            if a <= 0.04:
                dst[x, y] = (0, 0, 0, 0)
                continue
            dst[x, y] = (clamp((r - (1 - a) * 255) / a), clamp(g / a), clamp((b - (1 - a) * 255) / a),
                         int(round(a * 255)))
    return out


def resize(rgba, size):
    return rgba.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def write_tga(rgba, path):
    w, h = rgba.size
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 8])
    px = rgba.load()
    body = bytearray()
    for y in range(h - 1, -1, -1):          # bottom-left origin, like the addon's other TGAs
        for x in range(w):
            r, g, b, a = px[x, y]
            body += bytes((b, g, r, a))
    with open(path, "wb") as f:
        f.write(header + body)


sheet = Image.new("RGBA", (SIDE * 2 * 8, SIDE * 2 * 2), (70, 90, 60, 255))
missing = []
for i, key in enumerate(KEYS):
    path = os.path.join(src_dir, "emote-%s.png" % key)
    if not os.path.exists(path):
        missing.append(key)
        continue
    im = key_magenta(Image.open(path))
    box = im.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()
    im = im.crop(box)
    side = max(im.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(im, ((side - im.size[0]) // 2, (side - im.size[1]) // 2))
    inner = round(SIDE * FILL)
    out = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    out.alpha_composite(resize(square, (inner, inner)), ((SIDE - inner) // 2, (SIDE - inner) // 2))
    write_tga(out, os.path.join(out_dir, "Emote-%s.tga" % key))
    sheet.alpha_composite(resize(out, (SIDE * 2, SIDE * 2)), ((i % 8) * SIDE * 2, (i // 8) * SIDE * 2))
sheet.save(os.path.join(preview_dir, "emotes-preview.png"))
print("converted %d, missing: %s" % (len(KEYS) - len(missing), ", ".join(missing) or "none"))
