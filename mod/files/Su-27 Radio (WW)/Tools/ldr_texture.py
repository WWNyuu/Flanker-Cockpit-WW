# Texture atlas for the Su-27 loader plate: front artwork (paint, labels,
# scale) + colour swatches for the 3D parts.
import sys, math, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from ldr_layout import *

OUT = sys.argv[1] if len(sys.argv) > 1 else '../Textures/su27_ldr_plate.png'
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'
PAINT = (100, 115, 115)
CREAM = (232, 222, 188)
LBL = (44, 46, 46)


def P(x, y):
    return (x * PXMM, y * PXMM)


def text_img(text, cap_mm, col, squeeze=0.80):
    """text rendered then squeezed horizontally (ED's labels use a narrow face)"""
    f = ImageFont.truetype(FONT, int(cap_mm * PXMM * 1.42))
    bb = f.getbbox(text)
    w, h = bb[2] - bb[0] + 4, bb[3] - bb[1] + 4
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((2 - bb[0], 2 - bb[1]), text, font=f, fill=col + (255,))
    return im.resize((max(1, int(w * squeeze)), h), Image.LANCZOS)


def paste_c(dst, im, cx, cy):
    dst.alpha_composite(im, (int(round(cx - im.width / 2)), int(round(cy - im.height / 2))))


def label(dst, cx_mm, cy_mm, text, cap_mm=3.0, screws=False):
    t = text_img(text, cap_mm, CREAM)
    pad_x, pad_y = 1.4 * PXMM, 0.9 * PXMM
    extra = 2.6 * PXMM if screws else 0
    w, h = t.width + 2 * pad_x + 2 * extra, t.height + 2 * pad_y
    cx, cy = P(cx_mm, cy_mm)
    box = Image.new('RGBA', (int(w) + 8, int(h) + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(box)
    d.rounded_rectangle([4, 4, 4 + w, 4 + h], radius=int(0.8 * PXMM), fill=LBL + (255,), outline=(28, 30, 30, 255), width=3)
    d.line([(8, 6), (w, 6)], fill=(80, 82, 82, 255), width=2)          # top edge highlight
    if screws:
        for sx in (4 + extra / 2 + 3, 4 + w - extra / 2 - 3):
            r = 0.9 * PXMM
            d.ellipse([sx - r, 4 + h / 2 - r, sx + r, 4 + h / 2 + r], fill=(30, 32, 32, 255), outline=(120, 122, 118, 255), width=3)
            d.line([(sx - r * .7, 4 + h / 2), (sx + r * .7, 4 + h / 2)], fill=(120, 122, 118, 255), width=3)
    sh = Image.new('RGBA', box.size, (0, 0, 0, 0))
    sh.paste((0, 0, 0, 90), mask=box.split()[3])
    dst.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)), (int(cx - box.width / 2) + 2, int(cy - box.height / 2) + 3))
    paste_c(dst, box, cx, cy)
    paste_c(dst, t, cx, cy)


def paint(w, h, base, seed):
    rng = np.random.default_rng(seed)
    a = np.ones((h, w, 3)) * np.array(base, float)
    n1 = Image.fromarray((rng.normal(128, 40, (h // 8 + 1, w // 8 + 1))).clip(0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    n2 = rng.normal(0, 3.0, (h, w))
    a += ((np.asarray(n1, float) - 128) / 128 * 4.0)[..., None] + n2[..., None]
    return a


def main():
    img = Image.new('RGBA', (TEX_W, TEX_H), (0, 0, 0, 255))
    fw, fh = int(PW * PXMM), int(PH * PXMM)
    a = paint(fw, fh, PAINT, 7)
    # worn edges: lighter paint near the plate border
    yy, xx = np.mgrid[0:fh, 0:fw]
    edge = np.minimum.reduce([xx, yy, fw - 1 - xx, fh - 1 - yy]).astype(float)
    wear = np.clip(1 - edge / (1.6 * PXMM), 0, 1) ** 2
    rng = np.random.default_rng(3)
    wear *= (rng.random((fh, fw)) > 0.35)
    a += wear[..., None] * 38
    # grime around the knob and button (hand wear)
    for (cx, cy, r) in [(KNOB[0], KNOB[1], 15), (BTN[0], BTN[1], 9)]:
        d2 = ((xx - cx * PXMM) ** 2 + (yy - cy * PXMM) ** 2) / (r * PXMM) ** 2
        a -= np.clip(1 - d2, 0, 1)[..., None] * 9
    front = Image.fromarray(a.clip(0, 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(front)
    # bevel line around the edge
    d.rectangle([2, 2, fw - 3, fh - 3], outline=(70, 82, 82, 255), width=4)
    d.rectangle([7, 7, fw - 8, fh - 8], outline=(122, 136, 134, 255), width=2)
    # divider lines (cream, as on the stock panels)
    for x in DIV_X:
        d.line([P(x, DIV_Y[0]), P(x, DIV_Y[1])], fill=CREAM + (255,), width=int(0.45 * PXMM))
    # selector scale
    for i, name in enumerate(KNOB_POS):
        ang = math.radians(KNOB_ANG0 + i * KNOB_STEP)
        c, s = math.cos(ang), -math.sin(ang)
        r0, r1 = KNOB_R + 1.6, KNOB_R + 4.2
        d.line([P(KNOB[0] + c * r0, KNOB[1] + s * r0), P(KNOB[0] + c * r1, KNOB[1] + s * r1)],
               fill=CREAM + (255,), width=int(0.5 * PXMM))
        t = text_img(name, 3.2, CREAM)
        paste_c(front, t, *P(KNOB[0] + c * KNOB_SCALE_R, KNOB[1] + s * KNOB_SCALE_R))
    # window: dark recess (the 3D bezel sits around it)
    x0, y0 = WIN[0] - WIN_W / 2, WIN[1] - WIN_H / 2
    d.rectangle([P(x0, y0), P(x0 + WIN_W, y0 + WIN_H)], fill=(10, 14, 14, 255))
    # button guard ring shadow + lamp bezel shadows (soft)
    sh = Image.new('RGBA', front.size, (0, 0, 0, 0)); ds = ImageDraw.Draw(sh)
    for (cx, cy), r in [(BTN, BTN_GUARD_R + .6), (LAMP_GO, LAMP_BEZEL_R + .6), (LAMP_NOGO, LAMP_BEZEL_R + .6), (KNOB, KNOB_R + .8)]:
        ds.ellipse([P(cx - r + .6, cy - r + 1.0), P(cx + r + .6, cy + r + 1.0)], fill=(0, 0, 0, 120))
    front.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)))
    # labels
    label(front, TITLE[0], TITLE[1], 'ВВОД ДАННЫХ', 3.6, screws=True)
    label(front, KNOB_LABEL[0], KNOB_LABEL[1], 'КАССЕТА', 2.9)
    label(front, WIN_LABEL[0], WIN_LABEL[1], 'В РАБОТЕ', 2.9)
    label(front, BTN_LABEL[0], BTN_LABEL[1], 'ЗАГР', 3.2)
    label(front, LAMP_GO_LABEL[0], LAMP_GO_LABEL[1], 'ГОТОВ', 2.9)
    label(front, LAMP_NOGO_LABEL[0], LAMP_NOGO_LABEL[1], 'ОТКАЗ', 2.9)
    img.alpha_composite(front, (0, 0))

    # swatches
    d = ImageDraw.Draw(img)
    def sw(name, col):
        x0, x1 = SWATCH[name]
        d.rectangle([x0, SW_Y0, x1, SW_Y1], fill=col + (255,))
    sw('paint', PAINT)
    sw('black', (20, 20, 20))
    sw('red', (150, 30, 26))
    sw('lens_go', (28, 70, 34))
    sw('lens_nogo', (78, 18, 14))
    sw('white', (236, 236, 230))
    # chrome: vertical gradient
    x0, x1 = SWATCH['chrome']
    for y in range(SW_Y0, SW_Y1 + 1):
        t = (y - SW_Y0) / (SW_Y1 - SW_Y0)
        v = int(110 + 120 * math.sin(t * math.pi) ** 2)
        d.line([(x0, y), (x1, y)], fill=(v, v, v - 4, 255))
    # screw head: grey disc with a slot (the screw top maps onto this square)
    x0, x1 = SWATCH['screw']
    cx, cy, r = (x0 + x1) / 2, (SW_Y0 + SW_Y1) / 2, (x1 - x0) / 2 - 4
    d.rectangle([x0, SW_Y0, x1, SW_Y1], fill=(120, 126, 124, 255))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(150, 156, 152, 255), outline=(70, 74, 72, 255), width=6)
    a = math.radians(35)
    d.line([(cx - r * .8 * math.cos(a), cy - r * .8 * math.sin(a)), (cx + r * .8 * math.cos(a), cy + r * .8 * math.sin(a))],
           fill=(50, 54, 52, 255), width=14)
    # knob pointer top: black with a white line along its length (u axis)
    x0, x1 = SWATCH['pointer']
    d.rectangle([x0, SW_Y0, x1, SW_Y1], fill=(16, 16, 16, 255))
    cy = (SW_Y0 + SW_Y1) / 2
    d.rectangle([x0 + 30, cy - 9, x1 - 60, cy + 9], fill=(238, 238, 232, 255))
    d.polygon([(x1 - 60, cy - 26), (x1 - 8, cy), (x1 - 60, cy + 26)], fill=(238, 238, 232, 255))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.convert('RGB').save(OUT)
    print('saved', OUT, img.size)


if __name__ == '__main__':
    main()
