# Su-27 MFD (WW): bezel texture Textures/su27_mfd_bezel.png, 2048 x 2048
#   face art: the bezel front, 200 x 190 mm at 10 px/mm, from (0, 0)
#   swatches: row y 1920..2040, 190 px wide each (see SW below)
# Needs the preview drawing module (pages.py) and cairosvg.
import sys, io
sys.path.insert(0, '/home/claude/mfd')
import cairosvg, pages as P
from PIL import Image, ImageDraw
OUT = sys.argv[1] if len(sys.argv) > 1 else '/home/claude/mod/Textures/su27_mfd_bezel.png'
SW = {"paint": (0, "#1d1e20"), "cap": (200, "#33363a"), "capside": (400, "#26282b"), "screen": (600, "#030506"),
      "metal": (800, "#8d9094"), "rocker": (1000, "#2a2c2f"), "edge": (1200, "#121314")}
img = Image.new("RGB", (2048, 2048), "#1d1e20")
svg = P.bezel("", osbs=False, screen=False).replace('width="100%" height="100%"', 'width="2000" height="1900"')
face = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), background_color="#1b1c1e"))).convert("RGB")
img.paste(face, (0, 0))
d = ImageDraw.Draw(img)
for name, (x, col) in SW.items():
    d.rectangle([x, 1920, x + 189, 2039], fill=col)
img.save(OUT)
print("texture:", OUT, img.size)
