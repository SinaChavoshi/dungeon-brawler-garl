"""Draws the ability and item icons (original, CC0) into assets/icons/.

Each icon is 64 x 64: a radial gradient background, a simple glyph and a
bevelled frame, drawn at 4x and scaled down for smooth edges.

    python tools/make_icons.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
S = 256  # drawing size; saved at 64


def base(c1, c2):
    img = Image.new("RGBA", (S, S))
    px = img.load()
    for y in range(S):
        for x in range(S):
            d = min(1.0, math.hypot(x - S * 0.4, y - S * 0.35) / (S * 0.8))
            px[x, y] = tuple(int(c1[i] * (1 - d) + c2[i] * d) for i in range(3)) + (255,)
    return img


def finish(img, name):
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, S - 1, S - 1], outline=(20, 16, 12, 255), width=14)
    d.rectangle([10, 10, S - 11, S - 11], outline=(180, 150, 90, 255), width=5)
    shine = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shine).ellipse([-S * 0.3, -S * 0.75, S * 1.1, S * 0.35], fill=(255, 255, 255, 28))
    img = Image.alpha_composite(img, shine)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def glyph_layer():
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return layer, ImageDraw.Draw(layer)


def with_shadow(img, layer):
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 170), (8, 10), layer)
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(6)))
    return Image.alpha_composite(img, layer)


def fist(d, ox, oy, scale, color, outline):
    def r(x0, y0, x1, y1, rad=18):
        d.rounded_rectangle([ox + x0 * scale, oy + y0 * scale, ox + x1 * scale, oy + y1 * scale],
                            radius=rad * scale, fill=color, outline=outline, width=int(5 * scale))
    r(30, 70, 150, 170, 30)           # back of hand
    for i in range(4):
        r(40 + i * 28, 40, 66 + i * 28, 95, 12)  # knuckles
    r(10, 95, 70, 135, 16)            # thumb


def haymaker():
    img = base((255, 170, 80), (120, 30, 10))
    layer, d = glyph_layer()
    for i in range(5):
        a = math.radians(200 + i * 18)
        d.line([128 + math.cos(a) * 60, 140 + math.sin(a) * 60, 128 + math.cos(a) * 115, 140 + math.sin(a) * 115],
               fill=(255, 240, 180, 220), width=10)
    fist(d, 55, 70, 0.95, (80, 160, 240, 255), (20, 40, 90, 255))
    finish(with_shadow(img, layer), "haymaker")


def boot():
    img = base((200, 120, 255), (50, 10, 80))
    layer, d = glyph_layer()
    d.polygon([(70, 40), (130, 40), (130, 150), (205, 165), (215, 205), (60, 205), (60, 150)],
              fill=(120, 80, 50, 255), outline=(40, 20, 10, 255))
    d.rectangle([60, 190, 215, 212], fill=(60, 40, 25, 255))
    for i in range(3):
        d.line([20, 70 + i * 40, 55, 80 + i * 40], fill=(255, 255, 255, 200), width=9)
    finish(with_shadow(img, layer), "boot")


def belly_flop():
    img = base((120, 220, 255), (10, 60, 110))
    layer, d = glyph_layer()
    d.ellipse([50, 60, 206, 170], fill=(80, 160, 240, 255), outline=(20, 40, 90, 255), width=6)
    d.ellipse([90, 100, 166, 160], fill=(150, 200, 255, 255))
    d.ellipse([60, 175, 196, 215], fill=(130, 110, 90, 255))
    for x in (40, 110, 180):
        d.polygon([(x, 215), (x + 18, 190), (x + 36, 215)], fill=(200, 180, 150, 255))
    finish(with_shadow(img, layer), "belly_flop")


def dodge():
    img = base((140, 255, 160), (10, 80, 30))
    layer, d = glyph_layer()
    for i, alpha in enumerate([90, 150, 255]):
        x = 40 + i * 45
        d.ellipse([x, 70, x + 70, 190], fill=(80, 160, 240, alpha))
    d.polygon([(150, 128), (215, 128), (215, 100), (245, 140), (215, 180), (215, 152), (150, 152)],
              fill=(255, 255, 255, 255))
    finish(with_shadow(img, layer), "dodge")


def royal_spray():
    img = base((255, 140, 220), (90, 10, 70))
    layer, d = glyph_layer()
    for cx, cy, r in [(150, 110, 50), (190, 150, 40), (120, 160, 45), (175, 80, 30)]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(170, 230, 90, 210))
    d.polygon([(40, 60), (70, 30), (100, 60), (130, 30), (160, 60), (150, 90), (50, 90)],
              fill=(255, 215, 60, 255), outline=(120, 80, 0, 255))
    for x in (70, 100, 130):
        d.ellipse([x - 9, 52, x + 9, 70], fill=(255, 80, 140, 255))
    finish(with_shadow(img, layer), "royal_spray")


def quick_heal():
    img = base((255, 120, 120), (100, 10, 20))
    layer, d = glyph_layer()
    d.rectangle([103, 50, 153, 206], fill=(255, 255, 255, 255))
    d.rectangle([50, 103, 206, 153], fill=(255, 255, 255, 255))
    d.rectangle([113, 60, 143, 196], fill=(230, 40, 50, 255))
    d.rectangle([60, 113, 196, 143], fill=(230, 40, 50, 255))
    finish(with_shadow(img, layer), "quick_heal")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for make in (haymaker, boot, belly_flop, dodge, royal_spray, quick_heal):
        make()
    print("icons written to", os.path.abspath(OUT))
