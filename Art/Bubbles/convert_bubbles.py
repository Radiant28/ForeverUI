"""Converts the generated bubble PNGs (magenta background) into 32-bit TGA textures for ChatBubbles.lua.

usage: python -I Art/Bubbles/convert_bubbles.py Art/Bubbles <preview dir>  (needs Pillow; run from the addon root)
"""
import sys, os
from PIL import Image

src_dir = os.path.join(sys.argv[1], "source")
out_dir = sys.argv[1]
preview_dir = sys.argv[2]
# ChatBubbles.lua uses only variant 2 ("bronze, dark stone"); variants 1 and 3 (TGA and source PNG) were deleted
# 2026-11-28. A new variant: put bubble-<frame|tail|glow|gem>-v<N>.png into source/ and list N here.
VARIANTS = (2,)
CORNER = 128          # source px of a frame corner (all ornaments fit)
GLOW_CORNER = 96      # source px of a glow corner


def key_magenta(im):
    """RGB with a #FF00FF background -> RGBA, antialiased edges unmixed from magenta."""
    im = im.convert("RGB")
    out = Image.new("RGBA", im.size)
    src, dst = im.load(), out.load()
    w, h = im.size
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
            fr = (r - (1 - a) * 255) / a
            fg = g / a
            fb = (b - (1 - a) * 255) / a
            clamp = lambda v: int(max(0, min(255, round(v))))
            dst[x, y] = (clamp(fr), clamp(fg), clamp(fb), int(round(a * 255)))
    return out


def bbox(rgba):
    return rgba.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()


def resize(rgba, size):
    # Premultiplied resize: no dark or magenta fringe on the edges.
    return rgba.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def write_tga(rgba, path):
    w, h = rgba.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0, "power of two"
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 8])
    px = rgba.load()
    body = bytearray()
    for y in range(h - 1, -1, -1):          # bottom-left origin, like the addon's other TGAs
        for x in range(w):
            r, g, b, a = px[x, y]
            body += bytes((b, g, r, a))
    with open(path, "wb") as f:
        f.write(header + body)


report = []
for i in VARIANTS:
    # Frame: crop to the frame, 256x128.
    frame = key_magenta(Image.open(os.path.join(src_dir, "bubble-frame-v%d.png" % i)))
    box = bbox(frame)
    frame = frame.crop(box)
    fw, fh = frame.size
    frame_out = resize(frame, (256, 128))
    write_tga(frame_out, os.path.join(out_dir, "Bubble-Frame%d.tga" % i))
    report.append("frame%d crop=%s corner u=%.4f v=%.4f" % (i, box, CORNER / fw, CORNER / fh))

    # Tail: crop, scale to 64 wide, top-aligned in a 64x64 file.
    tail = key_magenta(Image.open(os.path.join(src_dir, "bubble-tail-v%d.png" % i)))
    tail = tail.crop(bbox(tail))
    tw, th = tail.size
    height = max(1, round(64 * th / tw))
    # Tail stone takes the frame's panel colour (generated tails are all slate blue).
    fpx = frame.load()
    samples = sorted(fpx[x, y][:3] for x in range(fw // 2 - 60, fw // 2 + 60, 6) for y in range(fh // 2 - 30, fh // 2 + 30, 6))
    panel = samples[len(samples) // 2]
    tpx = tail.load()
    stone = sorted(tpx[x, y][:3] for x in range(tw // 2 - 8, tw // 2 + 8) for y in range(4, th // 3) if tpx[x, y][3] > 250)
    base = stone[len(stone) // 2]
    for y in range(th):
        for x in range(tw):
            r, g, b, a = tpx[x, y]
            hi, lo = max(r, g, b), min(r, g, b)
            if a and hi < 120 and (hi - lo) < 40:
                k = [panel[c] / max(1, base[c]) for c in range(3)]
                tpx[x, y] = (min(255, int(r * k[0])), min(255, int(g * k[1])), min(255, int(b * k[2])), a)
    canvas = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    canvas.paste(resize(tail, (64, min(64, height))), (0, 0))
    write_tga(canvas, os.path.join(out_dir, "Bubble-Tail%d.tga" % i))
    report.append("tail%d crop=%dx%d height=%d/64" % (i, tw, th, min(64, height)))

    # Glow: grey level becomes alpha of white, 256x128.
    glow = Image.open(os.path.join(src_dir, "bubble-glow-v%d.png" % i)).convert("L")
    row = [glow.getpixel((x, glow.size[1] // 2)) for x in range(glow.size[0] // 2)]
    peak = max(range(len(row)), key=lambda x: row[x])
    inner = next(x for x in range(peak, len(row)) if row[x] < 10)
    white = Image.new("RGBA", glow.size, (255, 255, 255, 0))
    white.putalpha(glow)
    write_tga(resize(white, (256, 128)), os.path.join(out_dir, "Bubble-Glow%d.tga" % i))
    report.append("glow%d inner=%d src px corner u=%.4f v=%.4f" % (i, inner, GLOW_CORNER / glow.size[0],
                                                                  GLOW_CORNER / glow.size[1]))

    # Gem: split the grey-white crystal (tinted in game) from the bronze bezel.
    gem = key_magenta(Image.open(os.path.join(src_dir, "bubble-gem-v%d.png" % i)))
    gem = gem.crop(bbox(gem))
    side = max(gem.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(gem, ((side - gem.size[0]) // 2, (side - gem.size[1]) // 2))
    gem = resize(square, (64, 64))
    bezel = Image.new("RGBA", gem.size, (0, 0, 0, 0))
    crystal = Image.new("RGBA", gem.size, (0, 0, 0, 0))
    gp, bp, cp = gem.load(), bezel.load(), crystal.load()
    for y in range(64):
        for x in range(64):
            r, g, b, a = gp[x, y]
            if a == 0:
                continue
            hi, lo = max(r, g, b), min(r, g, b)
            sat = (hi - lo) / hi if hi else 0
            # Crystal: low saturation and not dark; the rest is bronze bezel.
            crystal_share = max(0.0, min(1.0, (0.28 - sat) / 0.12)) * max(0.0, min(1.0, (hi - 70) / 50.0))
            grey = int((r + g + b) / 3)
            cp[x, y] = (grey, grey, grey, int(a * crystal_share))
            bp[x, y] = (r, g, b, int(a * (1 - crystal_share)))
    write_tga(bezel, os.path.join(out_dir, "Bubble-Gem%d.tga" % i))
    write_tga(crystal, os.path.join(out_dir, "Bubble-Crystal%d.tga" % i))

    # Preview: the 9-slice at bubble sizes, like the game draws it (corner shown at 18 px).
    def nine(tex, w, h, c, u, v):
        tw, th = tex.size
        cu, cv = round(u * tw), round(v * th)
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        xs_src = [0, cu, tw - cu, tw]; ys_src = [0, cv, th - cv, th]
        xs_dst = [0, c, w - c, w]; ys_dst = [0, c, h - c, h]
        for a_ in range(3):
            for b_ in range(3):
                piece = tex.crop((xs_src[a_], ys_src[b_], xs_src[a_ + 1], ys_src[b_ + 1]))
                size = (xs_dst[a_ + 1] - xs_dst[a_], ys_dst[b_ + 1] - ys_dst[b_])
                if size[0] > 0 and size[1] > 0:
                    out.alpha_composite(resize(piece, size), (xs_dst[a_], ys_dst[b_]))
        return out

    sheet = Image.new("RGBA", (420, 150), (70, 90, 60, 255))
    for (w, h, x, y) in ((150, 38, 10, 20), (240, 70, 180, 10)):
        sheet.alpha_composite(nine(frame_out, w, h, 18, CORNER / fw, CORNER / fh), (x, y))
        t = resize(canvas, (16, 16))
        sheet.alpha_composite(t, (x + w // 2 - 8, y + h - 6))
        g = resize(gem, (14, 14))
        sheet.alpha_composite(g, (x + w // 2 - 7, y - 4))
    sheet.save(os.path.join(preview_dir, "bubble-look-%d.png" % i))

print("\n".join(report))
