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


# --- Items -------------------------------------------------------------------

def item(name, c1, c2, draw):
    img = base(c1, c2)
    layer, d = glyph_layer()
    draw(d)
    finish(with_shadow(img, layer), "item_" + name)


def i_bandage(d):
    d.rounded_rectangle([40, 95, 216, 161], radius=30, fill=(235, 220, 190, 255), outline=(120, 100, 70, 255), width=5)
    d.rectangle([105, 95, 151, 161], fill=(250, 245, 235, 255))
    for x in (115, 128, 141):
        for y in (110, 128, 146):
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(170, 150, 120, 255))
    d.ellipse([60, 105, 85, 130], fill=(170, 40, 40, 200))


def i_red_juice(d):
    d.rectangle([108, 30, 148, 75], fill=(200, 230, 255, 220), outline=(80, 100, 120, 255), width=4)
    d.rectangle([102, 22, 154, 36], fill=(140, 90, 50, 255))
    d.ellipse([55, 70, 201, 216], fill=(210, 30, 50, 255), outline=(90, 10, 20, 255), width=6)
    d.ellipse([85, 95, 120, 130], fill=(255, 160, 170, 200))


def i_time_coupon(d):
    d.polygon([(30, 70), (226, 70), (226, 186), (30, 186)], fill=(250, 230, 150, 255), outline=(150, 110, 30, 255))
    for y in range(80, 186, 22):
        d.ellipse([22, y, 38, y + 12], fill=(0, 0, 0, 0))
    d.ellipse([90, 88, 166, 164], fill=(255, 255, 255, 255), outline=(60, 40, 10, 255), width=6)
    d.line([128, 126, 128, 98], fill=(60, 40, 10, 255), width=7)
    d.line([128, 126, 150, 136], fill=(60, 40, 10, 255), width=7)


def i_skunk_treat(d):
    d.rounded_rectangle([60, 80, 196, 176], radius=40, fill=(160, 100, 50, 255), outline=(80, 45, 15, 255), width=6)
    for x, y in [(95, 110), (150, 105), (125, 145), (165, 150)]:
        d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(90, 50, 20, 255))
    d.polygon([(150, 40), (162, 70), (195, 72), (170, 92), (180, 124), (150, 106), (120, 124), (130, 92), (105, 72), (138, 70)],
              fill=(255, 220, 60, 255))


def i_fist_gear(color, spikes):
    def draw(d):
        fist(d, 55, 60, 0.95, color, (40, 30, 20, 255))
        if spikes:
            for i in range(4):
                x = 55 + (40 + i * 28 + 13) * 0.95
                d.polygon([(x - 10, 100), (x, 62), (x + 10, 100)], fill=(220, 220, 230, 255))
        else:
            d.rounded_rectangle([90, 95, 200, 125], radius=12, fill=(220, 180, 60, 255), outline=(110, 80, 10, 255), width=4)
    return draw


def i_sock(d):
    d.polygon([(95, 30), (160, 30), (160, 160), (215, 180), (215, 222), (95, 222)], fill=(240, 240, 230, 255), outline=(90, 90, 90, 255))
    for y in (50, 80, 110):
        d.rectangle([95, y, 160, y + 14], fill=(60, 120, 230, 255))


def i_belt(d):
    d.rounded_rectangle([20, 100, 236, 156], radius=12, fill=(150, 60, 160, 255), outline=(60, 20, 70, 255), width=5)
    d.rounded_rectangle([98, 90, 158, 166], radius=8, fill=(255, 215, 80, 255), outline=(120, 80, 10, 255), width=5)
    for x, y in [(45, 112), (70, 140), (190, 115), (212, 140)]:
        d.polygon([(x, y - 10), (x + 4, y), (x, y + 10), (x - 4, y)], fill=(255, 255, 255, 255))


def i_party_hat(d):
    d.polygon([(128, 25), (205, 215), (51, 215)], fill=(255, 90, 160, 255), outline=(120, 20, 70, 255))
    for (x, y, c) in [(110, 120, (255, 230, 60)), (150, 160, (80, 200, 255)), (100, 185, (120, 255, 120)), (140, 85, (255, 255, 255))]:
        d.ellipse([x - 10, y - 10, x + 10, y + 10], fill=c + (255,))
    d.ellipse([113, 12, 143, 42], fill=(255, 230, 60, 255))


def i_bone(d):
    d.line([70, 186, 186, 70], fill=(235, 225, 200, 255), width=30)
    for cx, cy in [(62, 172), (84, 196), (172, 62), (196, 84)]:
        d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=(235, 225, 200, 255))


ITEMS = [
    ("bandage", (230, 200, 160), (90, 60, 40), i_bandage),
    ("red_juice", (255, 150, 150), (90, 10, 20), i_red_juice),
    ("time_coupon", (130, 220, 255), (20, 60, 100), i_time_coupon),
    ("skunk_treat", (255, 170, 230), (90, 20, 70), i_skunk_treat),
    ("brass_knuckles", (200, 170, 110), (60, 40, 20), i_fist_gear((230, 190, 90, 255), False)),
    ("spiked_mitts", (255, 120, 90), (80, 20, 10), i_fist_gear((250, 250, 245, 255), True)),
    ("lonely_sock", (160, 210, 255), (20, 50, 100), i_sock),
    ("utility_belt", (220, 160, 255), (60, 20, 90), i_belt),
    ("party_hat", (255, 240, 140), (100, 70, 10), i_party_hat),
    ("bone_fragment", (150, 150, 150), (40, 40, 40), i_bone),
]


# --- Portraits for the unit frames ----------------------------------------------

def portrait(name, c1, c2, draw):
    img = base(c1, c2)
    layer, d = glyph_layer()
    draw(d)
    img = with_shadow(img, layer)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, S - 1, S - 1], fill=255)
    img.putalpha(mask)
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, "portrait_" + name + ".png"))


def p_garl(d):
    for side in (-1, 1):
        d.line([128 + side * 40, 70, 128 + side * 70, 20], fill=(70, 150, 235, 255), width=10)
        d.ellipse([128 + side * 70 - 16, 4, 128 + side * 70 + 16, 36], fill=(200, 255, 90, 255))
    d.ellipse([48, 60, 208, 240], fill=(70, 150, 235, 255), outline=(30, 70, 150, 255), width=6)
    for side in (-1, 1):
        d.ellipse([128 + side * 38 - 30, 105, 128 + side * 38 + 30, 165], fill=(250, 250, 245, 255))
        d.ellipse([128 + side * 34 - 13, 128, 128 + side * 34 + 13, 154], fill=(10, 10, 20, 255))
    d.arc([95, 170, 161, 215], 20, 160, fill=(20, 40, 90, 255), width=7)


def p_duchess(d):
    d.ellipse([50, 70, 206, 230], fill=(30, 28, 34, 255))
    d.polygon([(128, 70), (110, 230), (146, 230)], fill=(245, 245, 245, 255))
    for side in (-1, 1):
        d.polygon([(128 + side * 50, 95), (128 + side * 75, 40), (128 + side * 85, 110)], fill=(30, 28, 34, 255))
        d.ellipse([128 + side * 38 - 13, 135, 128 + side * 38 + 13, 161], fill=(255, 200, 80, 255))
    d.ellipse([116, 190, 140, 210], fill=(255, 130, 170, 255))
    d.polygon([(95, 72), (110, 40), (128, 62), (146, 40), (161, 72)], fill=(255, 215, 60, 255))


def p_skeleton(d):
    d.ellipse([60, 50, 196, 190], fill=(235, 228, 210, 255))
    d.rectangle([90, 170, 166, 225], fill=(235, 228, 210, 255))
    for side in (-1, 1):
        d.ellipse([128 + side * 33 - 24, 100, 128 + side * 33 + 24, 148], fill=(30, 20, 20, 255))
    d.polygon([(128, 150), (118, 172), (138, 172)], fill=(30, 20, 20, 255))
    for x in range(98, 166, 14):
        d.line([x, 190, x, 222], fill=(120, 110, 100, 255), width=4)


def p_dummy(d):
    d.ellipse([60, 40, 196, 176], fill=(195, 165, 110, 255), outline=(110, 85, 50, 255), width=6)
    d.rectangle([116, 170, 140, 240], fill=(115, 75, 45, 255))
    for r, c in [(40, (220, 40, 40)), (26, (255, 255, 255)), (12, (220, 40, 40))]:
        d.ellipse([128 - r, 108 - r, 128 + r, 108 + r], fill=c + (255,))


if __name__ == "__main__":
    for name, c1, c2, draw in [("garl", (120, 200, 255), (20, 50, 100), p_garl),
                               ("duchess", (255, 170, 220), (90, 20, 70), p_duchess),
                               ("skeleton", (200, 120, 100), (60, 10, 10), p_skeleton),
                               ("dummy", (200, 220, 160), (50, 70, 30), p_dummy)]:
        os.makedirs(OUT, exist_ok=True)
        portrait(name, c1, c2, draw)
    os.makedirs(OUT, exist_ok=True)
    for make in (haymaker, boot, belly_flop, dodge, royal_spray, quick_heal):
        make()
    for name, c1, c2, draw in ITEMS:
        item(name, c1, c2, draw)
    print("icons written to", os.path.abspath(OUT))
