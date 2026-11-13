"""Draws Lightbound's card textures into Media/ (TGA, power-of-two sizes).

Run from the addon folder:  python3 tools/make_media.py
Textures are white/gold with alpha so the game can tint them.
"""
import math
from PIL import Image, ImageDraw, ImageFilter

OUT = "Media/"


def sunburst(size=256, long_rays=12, short_rays=12):
    """The emblem's radiant star: long and short tapered rays from a soft core, white on alpha."""
    s = size * 4  # draw large, scale down for smooth edges
    c = s / 2
    img = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(img)

    def ray(angle, length, width, value):
        a = math.radians(angle)
        tip = (c + math.cos(a) * length, c + math.sin(a) * length)
        side = math.radians(90)
        l = (c + math.cos(a - side) * width, c + math.sin(a - side) * width)
        r = (c + math.cos(a + side) * width, c + math.sin(a + side) * width)
        d.polygon([l, tip, r], fill=value)

    for i in range(long_rays):
        ray(i * 360 / long_rays, s * 0.48, s * 0.055, 255)
    for i in range(short_rays):
        ray(i * 360 / short_rays + 180 / long_rays, s * 0.33, s * 0.04, 190)
    img = img.filter(ImageFilter.GaussianBlur(s * 0.006))
    # fade the rays out towards their tips so the star melts into the card
    fade = Image.radial_gradient("L").resize((s, s))  # 0 at centre, 255 at the edge
    fade = fade.point(lambda v: max(0, 255 - int(v * 1.15)))
    img = Image.composite(img, Image.new("L", (s, s), 0), fade)
    core = Image.radial_gradient("L").resize((s, s)).point(lambda v: max(0, 255 - v * 3))
    from PIL import ImageChops
    img = ImageChops.lighter(img, core.point(lambda v: int(v * 0.8)))
    img = img.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(img)
    out.save(OUT + "Sunburst.tga")


def ring(size=128, width=0.085):
    """A gilded ring for round icons: bright top edge, darker bottom, like hammered gold."""
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    px = img.load()
    c = (s - 1) / 2
    outer, inner = s * 0.5 - 2, s * (0.5 - width)
    for y in range(s):
        for x in range(s):
            r = math.hypot(x - c, y - c)
            if inner <= r <= outer:
                t = (r - inner) / (outer - inner)          # 0 inner edge .. 1 outer edge
                bevel = 1 - abs(t - 0.45) * 1.6             # bright ridge in the middle
                light = 0.55 + 0.45 * (-(y - c) / c)        # lit from above
                v = max(0.0, min(1.0, 0.35 + 0.65 * bevel * (0.6 + 0.4 * light)))
                px[x, y] = (int(255 * v), int(205 * v), int(105 * v), 255)
    img = img.resize((size, size), Image.LANCZOS)
    img.save(OUT + "Ring.tga")


def round_mask(size=64):
    """White disc: SetMask turns square spell icons round inside the ring."""
    s = size * 4
    img = Image.new("L", (s, s), 0)
    ImageDraw.Draw(img).ellipse((0, 0, s - 1, s - 1), fill=255)
    img = img.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    out.putalpha(img)
    out.save(OUT + "RoundMask.tga")


def diamond(size=16):
    """Small gilt stud for the card corners."""
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    h = s / 2
    d.polygon([(h, 2), (s - 3, h), (h, s - 3), (2, h)], fill=(225, 185, 95, 255))
    d.polygon([(h, 2), (s - 3, h), (h, h)], fill=(255, 230, 160, 255))  # lit facet
    img.resize((size, size), Image.LANCZOS).save(OUT + "Stud.tga")


if __name__ == "__main__":
    sunburst()
    ring()
    round_mask()
    diamond()
    print("wrote Media/Sunburst.tga, Ring.tga, RoundMask.tga, Stud.tga")
