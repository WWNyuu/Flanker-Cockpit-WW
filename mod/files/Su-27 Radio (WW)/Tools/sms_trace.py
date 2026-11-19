# Su-27 MFD (WW): the STORES page's Su-27 from behind, traced from a photo (pixel coords, left half;
# the right half is the mirror image about CX). Emits page units for mfd_page.lua.
import math, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
CX, WY, K = 682, 434, 0.80 / 667       # centre x, wing top y, page units per pixel
Y0 = 0.30                              # page y of the wing's top line
def ell(cx, cy, rx, ry, n=48, a0=0, a1=360):
    return [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in [a0 + (a1 - a0) * i / n for i in range(n + 1)]]
P = {}   # name: (points, closed, mirrored)
def part(name, pts, closed=True, mirror=True): P[name] = (pts, closed, mirror)
# wing: thin leading edge strip, root to tip; the inner part's flaperon band
part("wing", [(505, 433), (18, 435), (16, 440), (505, 439)])
part("flap", [(482, 439), (208, 439), (208, 472), (350, 478), (482, 466)])
part("flap_h", [(208, 452), (482, 450)], closed=False)                # flaperon hinge line
part("tip", [(14, 431), (88, 436), (88, 449), (72, 462), (40, 453), (14, 441)])
part("tip_n", [(14, 436), (88, 442)], closed=False)
# tailplane (seen a little from above: a thick triangle), its hinge line
part("stab", [(488, 456), (210, 519), (248, 552), (470, 550), (512, 521)])
part("stab_h", [(222, 528), (500, 506)], closed=False)
# fin with its dielectric tip, antenna fairings, rudder hinge
part("fin", [(485, 455), (489, 141), (492, 131), (496, 145), (502, 455)])
part("fin_tip", [(489, 176), (496, 176)], closed=False)
part("fin_rud", [(498, 300), (500, 450)], closed=False)
part("fin_a1", [(489, 192), (482, 198), (489, 206)], closed=False)
part("fin_a2", [(489, 212), (483, 217), (489, 223)], closed=False)
# ventral fin and the boom's side fairing at the fin root
part("vfin", [(480, 470), (487, 470), (486, 565), (481, 558)])
part("boom", [(474, 450), (488, 450), (488, 503), (476, 498)])
# fuselage hump to the canopy (open line, then mirrored)
part("hump", [(505, 433), (590, 432), (607, 429), (623, 417), (637, 398), (643, 391)], closed=False)
part("rail", [(643, 391), (643, 356), (651, 352)], closed=False)          # canopy rail fairing
part("hump_top", [(643, 391), (682, 389)], closed=False)
part("dorsal", ell(CX, 412, 20, 3, 20), mirror=False)
# canopy: outer frame and the rear hoop (single, centred)
part("canopy", [(652, 365), (652, 341)] + ell(CX, 341, 30, 25, 18, 180, 360) + [(712, 365)], closed=False, mirror=False)
part("hoop", [(656, 376), (656, 368)] + ell(CX, 368, 26, 25, 16, 180, 360) + [(708, 376)], closed=False, mirror=False)
part("seat", [(676, 358), (676, 350), (688, 350), (688, 358)], mirror=False)
# engine bay corner box and the beam between nozzle and tail boom
part("bay", [(613, 437), (628, 437), (628, 464), (613, 464)])
part("beam", [(628, 453), (648, 453), (648, 484), (628, 484)])
part("green", [(648, 467), (668, 467), (668, 480), (648, 480)])
# tail boom (stinger) end, antenna mast above it
part("cone", [(664, 455), (700, 455), (709, 470), (698, 492), (682, 501), (666, 492), (655, 470)], mirror=False)
part("cone_c", ell(CX, 476, 9, 9, 16), mirror=False)
part("mast", [(682, 455), (682, 428)], closed=False, mirror=False)
part("mast_t", [(677, 440), (687, 440)], closed=False, mirror=False)
# nozzles: shroud, petals' edge, throat, flame holder; petals drawn in Lua
NOZ = (564, 497, 58, 62)
part("noz_o", ell(564, 497, 58, 62, 48))
part("noz_i", ell(564, 498, 51, 54, 48))
part("noz_t", ell(564, 500, 33, 34, 40))
part("noz_f", ell(564, 500, 12, 12, 20))
# pylons: 2 (outer wing), 3 (inner wing, under the flaperon), 4 (under the
# nacelle), 5 (tunnel); 1 = the wingtip launcher itself
part("py2", [(139, 440), (151, 440), (149, 468), (141, 468)])
part("py3", [(295, 476), (305, 477), (303, 492), (297, 492)])
part("py4", [(570, 556), (580, 556), (579, 575), (571, 575)])
part("py5", [(652, 503), (662, 503), (661, 520), (653, 520)])
# under-nacelle fairing (station 4 / 7 pylon)
part("nac_f", [(548, 553), (580, 556), (590, 553)], closed=False)
def to_page(p, m=False):
    x = (p[0] - CX) * K; y = Y0 + (WY - p[1]) * K
    return (-x if m else x, y)
out = {}
for n, (pts, cl, mi) in P.items():
    out[n] = {"pts": [to_page(q) for q in pts], "closed": cl, "mirror": mi}
json.dump({"parts": out, "st": [to_page(q) for q in [(55, 460), (145, 468), (300, 492), (575, 575), (657, 520)]], "noz": [(NOZ[0] - CX) * K, Y0 + (WY - NOZ[1]) * K, 51 * K, 54 * K, 33 * K]}, open(os.path.join(HERE, "sms_trace.json"), "w"))
# overlay on the photo
from PIL import Image, ImageDraw
if len(sys.argv) < 2: sys.exit(0)          # photo given: draw the trace over it
im = Image.open(sys.argv[1]).convert('RGB')
d = ImageDraw.Draw(im)
for n, (pts, cl, mi) in P.items():
    for m in ([False, True] if mi else [False]):
        q = [((2 * CX - x) if m else x, y) for x, y in pts]
        if cl: q = q + [q[0]]
        d.line(q, fill=(255, 0, 255), width=2)
im.save(os.path.join(HERE, 'sms_trace_overlay.png'))
