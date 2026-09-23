"""Compose StartKind store images: app screen on the accent gradient, two-line caption above.
Mirrors Maren's pipeline (AppStore/screenshots/tools) but uses StartKind's own teal accent."""
from PIL import Image, ImageDraw, ImageFont
import os, sys, json

W, H = 1320, 2868
TOP = (24, 74, 57)      # darker shade of the accent (0.176,0.486,0.357)
BOT = (58, 150, 112)
CARD_W = 1003; CARD_X = (W - CARD_W)//2; CARD_Y = 580; RADIUS = 56
L1_Y, L2_Y, FS = 150, 330, 135
LATIN = ('/System/Library/Fonts/Helvetica.ttc', 1)
CJK = ('/System/Library/Fonts/Hiragino Sans GB.ttc', 2)

CAPS = {
 'en-US': [("One tangle in,","one step out"), ("Start small,","timer running"), ("Stuck?","There's still a step"),
           ("See your","own patterns"), ("Bills and letters,","read for you"), ("No account,","data stays on device")],
 'zh-Hans': [("只给你","下一步"), ("先做一小会儿","计时陪着你"), ("我卡住了","也有下一步"),
             ("看见自己的","规律"), ("事务阅读器","帮你读账单"), ("不需要账号","数据只在本机")],
}
ORDER = ['01_start','02_timer','03_stuck','04_patterns','05_admin','06_settingsPrivacy']

def gradient():
    g = Image.new('RGB', (1, H))
    for y in range(H):
        t = y/(H-1)
        g.putpixel((0, y), tuple(int(TOP[i] + (BOT[i]-TOP[i])*t) for i in range(3)))
    return g.resize((W, H))

def font_for(loc, size):
    p, i = CJK if loc.startswith('zh') else LATIN
    return ImageFont.truetype(p, size, index=i)

def trim_bottom(im):
    """Cut on a blank row so the card's rounded corner never slices a line of text."""
    px = im.convert('L').load(); w, h = im.size
    step = max(1, w//160)
    def uniform(y):
        vals = [px[x, y] for x in range(0, w, step)]
        return max(vals) - min(vals) <= 6
    for y in range(h-1, int(h*0.90), -1):
        if all(uniform(yy) for yy in range(y-5, y+1)):
            return im.crop((0, 0, w, y+1))
    return im

def main(root, locales):
    for loc in locales:
        out = f'{root}/{loc}'; os.makedirs(out, exist_ok=True)
        for n, stem in enumerate(ORDER, 1):
            src = f'{root}/raw/{loc}/{stem}.png'
            raw = trim_bottom(Image.open(src).convert('RGB'))
            shot = raw.resize((CARD_W, int(CARD_W*raw.height/raw.width)), Image.LANCZOS)
            canvas = gradient()
            mask = Image.new('L', shot.size, 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width-1, shot.height-1], RADIUS, fill=255)
            canvas.paste(shot, (CARD_X, CARD_Y), mask)
            d = ImageDraw.Draw(canvas)
            for text, y in zip(CAPS[loc][n-1], (L1_Y, L2_Y)):
                size = FS
                while size > 60 and d.textlength(text, font=font_for(loc, size)) > W-140:
                    size -= 5
                f = font_for(loc, size)
                d.text(((W - d.textlength(text, font=f))/2, y), text, font=f, fill=(255, 255, 255))
            canvas.save(f'{out}/{n:02d}_{stem.split("_",1)[1]}.png')
        print(loc, 'composed', len(ORDER))

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2:] or ['en-US', 'zh-Hans'])
