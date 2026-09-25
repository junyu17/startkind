"""Composes raw StartKind screenshots onto a branded gradient with a
two-line caption above each, matching the App Store 6.9" iPhone size
(1320x2868). Colors are StartKind's own accent (deep teal-green from
StartKind/Resources/Assets.xcassets/AccentColor.colorset), not Maren's.

Usage: python3 compose_iphone_ja.py
Reads from  ../v1.0.1/raw/<locale>/NN_<name>.png
Writes to   ../v1.0.1/<locale>/NN_<name>.png
"""
from PIL import Image, ImageDraw, ImageFont
import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
RAW_DIR = os.path.join(ROOT, "..", "v1.1", "raw")
OUT_DIR = os.path.join(ROOT, "..", "v1.1")

W, H = 1320, 2868
# StartKind's AccentColor (deep teal-green): srgb(0.176, 0.486, 0.357).
# TOP is a darker shade of it, BOTTOM a slightly brighter one, so the card
# sits on a gradient built from the app's own brand color rather than a
# generic one.
TOP = (25, 68, 50)
BOT = (61, 167, 123)
CARD_W = 1003
CARD_X = (W - CARD_W) // 2
CARD_Y = 580
RADIUS = 56
L1_Y = 150
L2_Y = 330
FS = 135

LATIN = ("/System/Library/Fonts/Helvetica.ttc", 1)  # Bold
# PIL cannot open PingFang; Hiragino Sans GB is the CJK face that renders
# Simplified Chinese correctly (index 2 = its bold-ish "W6" weight).
CJK = ("/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc", 0)

SHOTS = ["01_start", "02_timer", "03_stuck", "04_patterns", "05_admin", "06_settingsPrivacy"]

with open(os.path.join(ROOT, "captions_ja.json")) as f:
    CAPTIONS = json.load(f)


def trim_bottom(im):
    """Crop off the screen's trailing uniform-color rows so the card's
    rounded bottom corners land on blank space instead of cutting text."""
    w, h = im.size
    px = im.convert("L").load()
    limit = int(h * 0.10)
    step = max(1, w // 160)

    def uniform(y):
        vals = [px[x, y] for x in range(0, w, step)]
        return max(vals) - min(vals) <= 6

    for y in range(h - 1, h - limit, -1):
        if all(uniform(yy) for yy in range(y - 5, y + 1)):
            return im.crop((0, 0, w, y + 1))
    return im


def gradient():
    g = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / (H - 1)
        g.putpixel((0, y), tuple(int(TOP[i] + (BOT[i] - TOP[i]) * t) for i in range(3)))
    return g.resize((W, H))


def font_for(loc, size):
    path, index = CJK if loc in ("zh-Hans", "ja") else LATIN
    return ImageFont.truetype(path, size, index=index)


def fit(d, text, loc, maxw):
    size = FS
    while size > 60:
        f = font_for(loc, size)
        if d.textlength(text, font=f) <= maxw:
            return f
        size -= 5
    return font_for(loc, 60)


def compose(loc):
    out = os.path.join(OUT_DIR, loc)
    os.makedirs(out, exist_ok=True)
    for stem in SHOTS:
        src_path = os.path.join(RAW_DIR, loc, f"{stem}.png")
        src = trim_bottom(Image.open(src_path).convert("RGB"))
        shot = src.resize((CARD_W, int(CARD_W * src.height / src.width)), Image.LANCZOS)

        canvas = gradient()
        mask = Image.new("L", shot.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width - 1, shot.height - 1], RADIUS, fill=255)
        canvas.paste(shot, (CARD_X, CARD_Y), mask)

        d = ImageDraw.Draw(canvas)
        lines = CAPTIONS[loc][stem]
        for text, y in zip(lines, (L1_Y, L2_Y)):
            f = fit(d, text, loc, W - 140)
            w = d.textlength(text, font=f)
            d.text(((W - w) / 2, y), text, font=f, fill=(255, 255, 255))

        assert canvas.size == (W, H), f"{loc}/{stem} wrong size {canvas.size}"
        canvas.save(os.path.join(out, f"{stem}.png"))
    print(loc, "done")


if __name__ == "__main__":
    for locale in ("ja",):
        compose(locale)
