# Su-27 MFD (WW): the 4477th TAES "Red Eagles" emblem for the MENU page, drawn as
# vector shapes and written as Cockpit/Textures/IndicationTextures/s27mfd_badge.dds
# (needs: pip install cairosvg pillow)
import math, cairosvg, io, os
HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, '..', 'Cockpit', 'Textures', 'IndicationTextures', 's27mfd_badge.dds')
from PIL import Image
RED, GREY, NAVY, WHITE = "#d0232a", "#c9cdd3", "#1c2340", "#f4f4f2"
CX, CY, R = 500, 460, 410
PX, PY = 360, 360          # centre of the grey pocket (and of the feather bands)
def pt(cx, cy, r, deg): a = math.radians(deg); return cx + r * math.cos(a), cy + r * math.sin(a)
def arc(cx, cy, r, a0, a1, sweep=1):
    x0, y0 = pt(cx, cy, r, a0); x1, y1 = pt(cx, cy, r, a1)
    span = (a1 - a0) % 360 if sweep == 1 else (a0 - a1) % 360
    large = 1 if span > 180 else 0
    return f"M {x0:.1f} {y0:.1f} A {r} {r} 0 {large} {sweep} {x1:.1f} {y1:.1f}"
def star(cx, cy, Ro, Ri):
    p = []
    for k in range(10):
        a = math.radians(-90 + k * 36); r = Ro if k % 2 == 0 else Ri
        p.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return " ".join(p)
bands = ""
for r in (282, 330, 378):
    bands += f'<path d="{arc(PX, PY, r, -62, 168)}" fill="none" stroke="{GREY}" stroke-width="22" stroke-linecap="round"/>'
# eagle head and neck inside the pocket (beak to the left)
eagle = ("M 600 560 C 560 470, 520 380, 470 300 C 440 255, 400 222, 345 214 "
         "C 290 207, 230 222, 192 248 C 172 262, 160 280, 158 300 "
         "C 172 288, 188 282, 204 284 C 214 286, 218 296, 214 308 "
         "C 236 290, 262 286, 286 296 C 306 306, 312 330, 306 360 "
         "C 298 410, 262 460, 200 500 C 170 520, 140 532, 110 540 "
         "C 260 580, 450 590, 600 560 Z")
title = arc(PX, PY, 188, 138, 292)
scroll_top, scroll_bot = 640, 770       # radii around (500, 300)
def sarc(r, x0, x1):
    a0 = math.degrees(math.acos((x1 - 500) / r)); a1 = math.degrees(math.acos((x0 - 500) / r))
    return a0, a1
SC = (500, 250)
def scroll_path():
    a0, a1 = 52, 128
    p0 = pt(*SC, scroll_top, a0); p1 = pt(*SC, scroll_top, a1); q1 = pt(*SC, scroll_bot, a1); q0 = pt(*SC, scroll_bot, a0)
    return (f"M {p0[0]:.1f} {p0[1]:.1f} A {scroll_top} {scroll_top} 0 0 1 {p1[0]:.1f} {p1[1]:.1f} "
            f"L {q1[0]:.1f} {q1[1]:.1f} A {scroll_bot} {scroll_bot} 0 0 0 {q0[0]:.1f} {q0[1]:.1f} Z")
lab = arc(SC[0], SC[1], 722, 128, 52, 0)
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1080" viewBox="0 0 1000 1080">
<defs><clipPath id="disc"><circle cx="{CX}" cy="{CY}" r="{R}"/></clipPath>
<path id="title" d="{title}"/><path id="lab" d="{lab}"/></defs>
<path d="{scroll_path()}" fill="{GREY}" stroke="{NAVY}" stroke-width="20" stroke-linejoin="round"/>
<text font-family="DejaVu Sans" font-weight="bold" font-size="92" fill="{NAVY}" letter-spacing="4">
<textPath href="#lab" startOffset="50%" text-anchor="middle">4477th TAES</textPath></text>
<circle cx="{CX}" cy="{CY}" r="{R + 14}" fill="{NAVY}"/>
<circle cx="{CX}" cy="{CY}" r="{R}" fill="{RED}"/>
<g clip-path="url(#disc)">
<circle cx="{PX}" cy="{PY}" r="236" fill="{GREY}"/>
{bands}
<path d="{eagle}" fill="{RED}" transform="translate(55,40)"/>
<path d="M 300 246 C 288 236, 262 236, 250 252 C 268 254, 286 256, 300 246 Z" fill="{WHITE}" transform="translate(55,40)"/>
</g>
<text font-family="DejaVu Sans" font-weight="bold" font-size="56" fill="{RED}" letter-spacing="2">
<textPath href="#title" startOffset="50%" text-anchor="middle">RED EAGLES</textPath></text>
<polygon points="{star(585, 600, 175, 70)}" fill="{WHITE}"/>
</svg>'''
png = cairosvg.svg2png(bytestring=svg.encode(), output_width=1000, output_height=1080)
im = Image.open(io.BytesIO(png)).convert("RGBA")
sq = Image.new("RGBA", (1080, 1080), (0, 0, 0, 0)); sq.paste(im, (40, 0), im)
sq = sq.resize((512, 512), Image.LANCZOS)

# DDS: uncompressed RGBA with the full mip chain (DXT5 blurs the red / grey edges and the small text)
import struct
def dds_with_mips(img, path):
    levels, cur = [], img
    while True:
        b = io.BytesIO(); cur.save(b, format='DDS'); levels.append(b.getvalue())
        if cur.width <= 4 or cur.height <= 4: break
        cur = cur.resize((cur.width // 2, cur.height // 2), Image.LANCZOS)
    head = bytearray(levels[0][:128])
    struct.pack_into('<I', head, 8, struct.unpack_from('<I', head, 8)[0] | 0x20000)
    struct.pack_into('<I', head, 28, len(levels))
    struct.pack_into('<I', head, 108, struct.unpack_from('<I', head, 108)[0] | 0x8 | 0x400000)
    with open(path, 'wb') as f:
        f.write(head)
        for lv in levels: f.write(lv[128:])
    return len(levels)
print(dds_with_mips(sq, TEX), 'mip levels')
