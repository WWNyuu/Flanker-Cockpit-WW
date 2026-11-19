# Su-27 Radio (WW) 1.3: texture of the Su-33 side unit, Textures/su33_pod.png
#   2048 x 2048
#   face art: the unit's face, 170 x 88 mm at 10 px/mm, from (0, 0)
#   key tops: 12 keys, 180 x 110 px each at (col * 200, 1000 + row * 130)
#   swatches: row y 1900..2040, 190 px wide each (POD_SW in su27_ldr_plate.py)
# Layout numbers = Tools/su27_ldr_plate.py (POD_*, RAD_*).
import sys, os
from PIL import Image, ImageDraw, ImageFont
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "Textures", "su33_pod.png")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONTB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
PX = 10.0
POD_W, POD_H = 170.0, 88.0
POD_KEY_X = (15.0, 37.0, 59.0)
POD_KEY_Y = (20.0, 37.0, 54.0, 71.0)
POD_KEY_W, POD_KEY_H = 18.0, 11.0
KEYS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "СБР", "0", "ВВОД"]
POD_RAD_X, POD_RAD_Y, RAD_S, RAD_LC = 121.0, 24.0, 0.56, (23.2, -2.9)
RAD_WIN_Y = 14.02
RAD_WINS = {"КВ": (-37.11, -23.27), "УКВ": (34.86, 48.69)}
RAD_KNOBS = {"KV": (-30.05, -19.90), "UKV": (41.85, -19.95)}
RAD_VOL = {"VKV": (-3.18, 10.82), "VUKV": (84.42, 12.45)}
POD_LDR_X, POD_LDR_Y, LDR_W, LDR_H = 121.0, 66.6, 82.5, 35.5

PAINT, EDGE, CAP, CAPSIDE, INK = "#1d1e20", "#121314", "#2c2e32", "#232528", (226, 228, 230)
img = Image.new("RGB", (2048, 2048), PAINT)
d = ImageDraw.Draw(img)
def f(mm, bold=False): return ImageFont.truetype(FONTB if bold else FONT, int(mm * PX))
def P(x, y): return (x * PX, y * PX)
def text(x, y, s, mm, bold=False, fill=INK):
    d.text(P(x, y), s, font=f(mm, bold), fill=fill, anchor="mm")
def rad(x, y):      # radio layout (Su-27 panel mm, y up) -> pod mm
    return POD_RAD_X + (x - RAD_LC[0]) * RAD_S, POD_RAD_Y - (y - RAD_LC[1]) * RAD_S

# --- face ---------------------------------------------------------------------
d.rectangle([0, 0, POD_W * PX - 1, POD_H * PX - 1], fill=PAINT)
d.rectangle([0, 0, POD_W * PX - 1, POD_H * PX - 1], outline=EDGE, width=8)
for x, y in [(4.5, 4.5), (POD_W - 4.5, 4.5), (4.5, POD_H - 4.5), (POD_W - 4.5, POD_H - 4.5)]:
    d.ellipse([*P(x - 1.8, y - 1.8), *P(x + 1.8, y + 1.8)], fill="#55585c", outline="#2a2b2e", width=3)
    d.line([*P(x - 1.2, y), *P(x + 1.2, y)], fill="#1a1a1c", width=4)
text(37.0, 7.5, "ВВОД ДАННЫХ МФИ", 2.9)
# key wells (a darker frame round each key)
for i in range(12):
    x, y = POD_KEY_X[i % 3], POD_KEY_Y[i // 3]
    d.rounded_rectangle([*P(x - POD_KEY_W / 2 - 1.2, y - POD_KEY_H / 2 - 1.2), *P(x + POD_KEY_W / 2 + 1.2, y + POD_KEY_H / 2 + 1.2)],
                        radius=int(1.5 * PX), fill=EDGE)
d.line([*P(73, 6), *P(73, POD_H - 6)], fill=EDGE, width=6)
d.line([*P(77, 47.3), *P(POD_W - 6, 47.3)], fill=EDGE, width=6)
# radio: black windows, labels
for name, (c1, c2) in RAD_WINS.items():
    cx = (c1 + c2) / 2
    x0, y0 = rad(cx - 13.8 - 0.4, RAD_WIN_Y + 9.6 + 0.4)
    x1, y1 = rad(cx + 13.8 + 0.4, RAD_WIN_Y - 9.6 - 0.4)
    d.rectangle([*P(x0, y0), *P(x1, y1)], fill="#040606")
    lx, ly = rad(cx, RAD_WIN_Y + 15.5)
    text(lx, ly, name, 3.0, bold=True)
for key, (x, y) in RAD_KNOBS.items():
    lx, ly = rad(x, y - 15.8 - 3.0)
    text(lx, ly + 0.6, "КАНАЛ", 1.9)
for key, (x, y) in RAD_VOL.items():
    lx, ly = rad(x, y - 7.8 - 3.5)
    text(lx, ly, "ГРОМК", 1.9)
# loader plate: a dark seat a little bigger than the plate
d.rectangle([*P(POD_LDR_X - LDR_W / 2 - 0.8, POD_LDR_Y - LDR_H / 2 - 0.8), *P(POD_LDR_X + LDR_W / 2 + 0.8, POD_LDR_Y + LDR_H / 2 + 0.8)], fill=EDGE)

# --- key tops -----------------------------------------------------------------
for i, s in enumerate(KEYS):
    u0, v0 = (i % 3) * 200, 1000 + (i // 3) * 130
    d.rectangle([u0, v0, u0 + 179, v0 + 109], fill=CAP)
    d.rectangle([u0, v0, u0 + 179, v0 + 109], outline="#16171a", width=5)
    d.rectangle([u0 + 8, v0 + 6, u0 + 171, v0 + 14], fill="#3b3e43")
    d.text((u0 + 90, v0 + 58), s, font=f(5.6 if len(s) == 1 else 3.6, True), fill=INK, anchor="mm")

# --- swatches -------------------------------------------------------------------
for name, (x, col) in {"paint": (0, PAINT), "capside": (200, CAPSIDE), "black": (400, "#060707"), "edge": (600, EDGE)}.items():
    d.rectangle([x, 1900, x + 189, 2039], fill=col)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
img.save(OUT)
print("texture:", OUT, img.size)
