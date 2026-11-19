# Printed radio channel card (paper, ruled, headings) + the handwriting font atlas.
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from crd_layout import *

OUT_CARD = sys.argv[1] if len(sys.argv) > 1 else '../Textures/su27_crd_card.png'
OUT_FONT = sys.argv[2] if len(sys.argv) > 2 else '../Cockpit/Textures/IndicationTextures/su27_hand_font.dds'
OUT_FONT_LUA = sys.argv[3] if len(sys.argv) > 3 else '../Cockpit/Scripts/LDR/indicator/hand_font.lua'
PRINT = '/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf'
HAND = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Fonts', 'BadScript-Regular.ttf')

def P(x, y): return (x * PXMM, y * PXMM)

# ---------------- card ----------------
w, h = int(CW * PXMM), int(CH * PXMM)
rng = np.random.default_rng(11)
base = np.ones((h, w, 3)) * np.array([212, 210, 199], float)
blot = Image.fromarray((rng.normal(128, 40, (h // 12 + 1, w // 12 + 1))).clip(0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
base += ((np.asarray(blot, float) - 128) / 128 * 5)[..., None] + rng.normal(0, 2.5, (h, w))[..., None]
yy, xx = np.mgrid[0:h, 0:w]
edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy]).astype(float)
base -= np.clip(1 - edge / (2.5 * PXMM), 0, 1)[..., None] ** 2 * 22          # grubby edges
card = Image.fromarray(base.clip(0, 255).astype(np.uint8)).convert('RGBA')
d = ImageDraw.Draw(card)
INK = (28, 28, 30, 255)

def ptext(txt, cx, cy, cap_mm, squeeze=0.78, anchor='c'):
    f = ImageFont.truetype(PRINT, int(cap_mm * PXMM * 1.38))
    bb = f.getbbox(txt)
    tw, th = bb[2] - bb[0] + 4, bb[3] - bb[1] + 4
    im = Image.new('RGBA', (tw, th), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((2 - bb[0], 2 - bb[1]), txt, font=f, fill=INK)
    im = im.resize((max(1, int(tw * squeeze)), th), Image.LANCZOS)
    x, y = P(cx, cy)
    card.alpha_composite(im, (int(x - im.width / 2), int(y - im.height / 2)))

ptext('КАНАЛЫ РАДИОСВЯЗИ', CW / 2, 4.6, 3.2)
lw = max(2, int(0.28 * PXMM))
for hx in HALF_X:
    for i, (a, b) in enumerate(zip(COLS[:-1], COLS[1:])):
        name = ['N\nКАН', 'ЧАСТОТА\nМГц', 'РАДИОСТАНЦИЯ', 'ПОЗЫВНОЙ'][i]
        if '\n' in name:
            t1, t2 = name.split('\n')
            ptext(t1, hx + (a + b) / 2, 8.75, 1.5, 0.8); ptext(t2, hx + (a + b) / 2, 10.75, 1.5, 0.8)
        else:
            ptext(name, hx + (a + b) / 2, 9.7, 2.0, 0.66 if len(name) > 9 else 0.76)
    # vertical rules
    for c in COLS[:-1] if hx == HALF_X[0] else COLS[1:-1]:
        d.line([P(hx + c, HEAD_Y[0]), P(hx + c, ROW0 + ROWS * ROW_H)], fill=INK, width=lw)
# horizontal rules
d.line([P(HALF_X[0], HEAD_Y[0]), P(HALF_X[1] + HALF_W, HEAD_Y[0])], fill=INK, width=lw)
for r in range(ROWS + 1):
    y = ROW0 + r * ROW_H
    d.line([P(HALF_X[0], y), P(HALF_X[1] + HALF_W, y)], fill=INK, width=lw if r else lw + 1)
# double rule between the halves
for xx_ in (HALF_X[1] - 0.35, HALF_X[1] + 0.35, HALF_X[1] + HALF_W):
    d.line([P(xx_, HEAD_Y[0]), P(xx_, ROW0 + ROWS * ROW_H)], fill=INK, width=lw)
card = card.filter(ImageFilter.GaussianBlur(0.6))
atlas = Image.new('RGB', (TEX_W, TEX_H), (200, 198, 188))
atlas.paste(card.convert('RGB'), (0, 0))
os.makedirs(os.path.dirname(OUT_CARD), exist_ok=True)
atlas.save(OUT_CARD)
print('card', OUT_CARD, card.size)

# ---------------- handwriting font atlas (ED layout: 16 x 16 cells) ----------------
CELL, GRID, FS = 128, 16, 86
BASE = 90                                   # baseline in the cell
chars = list(range(32, 127)) + list(range(1040, 1104)) + [1025, 1105, 8470]
font = ImageFont.truetype(HAND, FS)
atl = Image.new('LA', (CELL * GRID, CELL * GRID), (255, 0))
entries = []
for k, code in enumerate(chars):
    ch = chr(code)
    cx, cy = (k % GRID) * CELL, (k // GRID) * CELL
    g = Image.new('LA', (CELL, CELL), (255, 0))
    gd = ImageDraw.Draw(g)
    bb = font.getbbox(ch, anchor='ls')
    lb = min(0, bb[0])
    gd.text((5 - lb, BASE), ch, font=font, fill=(255, 255), anchor='ls', stroke_width=2, stroke_fill=(255, 255))  # ballpoint weight
    adv = font.getlength(ch)
    width = int(min(CELL - 2, max(10, math.ceil(adv - lb + 8))))
    if code == 32: width = 26
    atl.paste(g, (cx, cy))
    entries.append((code, width))
cap = -font.getbbox('Н', anchor='ls')[1]
xh = -font.getbbox('х', anchor='ls')[1]
rgba = Image.merge('RGBA', (Image.new('L', atl.size, 255),) * 3 + (atl.split()[1],))
os.makedirs(os.path.dirname(OUT_FONT), exist_ok=True)
rgba.save(OUT_FONT, pixel_format='DXT5')
print('font', OUT_FONT, 'chars', len(entries), 'cap px', cap)
with open(OUT_FONT_LUA, 'w', encoding='utf-8') as f:
    f.write('-- Su-27 Radio (WW): handwriting font for the channel card (Bad Script, SIL OFL 1.1)\n')
    f.write('-- made by Tools\\crd_texture.py: 16 x 16 cells of 128 px, glyph in the left <width> px\n')
    f.write('HAND_FONT_CAP = %d / %d      -- capital height / cell height\n' % (cap, CELL))
    f.write('HAND_FONT_XH = %d / %d       -- lowercase / digit height / cell height\n' % (xh, CELL))
    f.write('HAND_FONT = {\n\ttexture    = LockOn_Options.script_path .. "../Textures/IndicationTextures/su27_hand_font.dds",\n')
    f.write('\tsize       = {16, 16},\n\tresolution = {2048, 2048},\n\tdefault    = {64, 128},\n\tchars      = {\n')
    for code, wd in entries:
        f.write('\t\t{%d, %d, 128},\n' % (code, wd))
    f.write('\t},\n}\n')
print('lua', OUT_FONT_LUA)

# ---------------- mip chain (Pillow writes one level; DCS likes the full chain) ----------------
import io, struct
def dds_with_mips(img, path):
    levels, cur = [], img
    while True:
        b = io.BytesIO(); cur.save(b, format='DDS', pixel_format='DXT5'); levels.append(b.getvalue())
        if cur.width <= 4 or cur.height <= 4: break
        cur = cur.resize((cur.width // 2, cur.height // 2), Image.LANCZOS)
    head = bytearray(levels[0][:128])
    flags = struct.unpack_from('<I', head, 8)[0] | 0x20000          # DDSD_MIPMAPCOUNT
    struct.pack_into('<I', head, 8, flags)
    struct.pack_into('<I', head, 28, len(levels))
    caps = struct.unpack_from('<I', head, 108)[0] | 0x8 | 0x400000    # COMPLEX | MIPMAP
    struct.pack_into('<I', head, 108, caps)
    with open(path, 'wb') as f:
        f.write(head)
        for lv in levels: f.write(lv[128:])
    return len(levels)
n = dds_with_mips(rgba, OUT_FONT)
print('font with', n, 'mip levels')
