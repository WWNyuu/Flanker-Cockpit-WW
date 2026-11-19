# Texture for the radio knob overlays: knurled side + top with pointer.
import sys, math, os
from PIL import Image, ImageDraw, ImageFilter
OUT = sys.argv[1] if len(sys.argv) > 1 else '../Textures/su27_rad_knobs.png'
W, H = 1024, 512
im = Image.new('RGB', (W, H), (14, 14, 14))
d = ImageDraw.Draw(im)
# left half (0..511): knurl - one groove per side face (u across = one groove)
for x in range(0, 512):
    t = x / 511.0
    v = 16 + int(26 * math.sin(t * math.pi) ** 2)          # rounded rib, dark groove edges
    d.line([(x, 0), (x, 255)], fill=(v, v, v))
# plain black + white swatches (bottom-left)
d.rectangle([0, 256, 255, 511], fill=(18, 18, 18))
d.rectangle([256, 256, 511, 511], fill=(236, 236, 230))
# right half (512..1023, 0..511): knob top, pointer along +u (to the right)
cx, cy, r = 768, 256, 250
top = Image.new('RGB', (512, 512), (14, 14, 14))
td = ImageDraw.Draw(top)
td.ellipse([6, 6, 506, 506], fill=(22, 22, 22), outline=(40, 40, 40), width=10)
td.ellipse([200, 200, 312, 312], fill=(30, 30, 30))                  # centre boss
td.rectangle([256, 244, 470, 268], fill=(240, 240, 232))               # pointer line
td.polygon([(470, 222), (504, 256), (470, 290)], fill=(240, 240, 232))  # arrow
im.paste(top, (512, 0))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
im.save(OUT)
print('saved', OUT)
