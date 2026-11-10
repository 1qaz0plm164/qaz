"""Compose front / side / back renders into one presentation sheet per jacket.

python3 render/compose.py <render_dir>
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

D = sys.argv[1] if len(sys.argv) > 1 else "renders"
TITLES = {
    "short": "Пуховик короткий с капюшоном · алый · полиэстер",
    "long": "Пуховик удлинённый · молочный · полиэстер",
}
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def gradient(w, h, top=(238, 239, 241), bottom=(205, 208, 212)):
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        g.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return g.resize((w, h))


for v, title in TITLES.items():
    views = [Image.open(os.path.join(D, f"{v}_{n}.png")) for n in ("front", "side", "back")]
    if not all(views):
        continue
    w, h = views[0].size
    crop = int(w * 0.12)  # trim empty side margins so the three views sit closer
    cw = w - 2 * crop
    head = int(h * 0.07)
    foot = int(h * 0.05)
    sheet = gradient(cw * 3, h + head + foot)
    for i, im in enumerate(views):
        sheet.paste(im.crop((crop, 0, w - crop, h)), (i * cw, head), im.crop((crop, 0, w - crop, h)))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.truetype(FONT, int(h * 0.026))
    fs = ImageFont.truetype(FONT, int(h * 0.018))
    d.text((cw * 1.5, head * 0.55), title + " · манекен 168 см", fill=(60, 62, 66), font=f, anchor="mm")
    for i, n in enumerate(("спереди", "сбоку", "сзади")):
        d.text((cw * i + cw / 2, h + head + foot * 0.4), n, fill=(90, 92, 96), font=fs, anchor="mm")
    sheet.save(os.path.join(D, f"{v}_sheet.png"))
    print("saved", v)
