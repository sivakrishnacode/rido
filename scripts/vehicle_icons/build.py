"""Builds the apps' vehicle illustrations from the owner's renders in docs/design/vechile/.

    python3 scripts/vehicle_icons/build.py            # writes packages/tamiltaxi_ui/assets/vehicles/<kind>.webp
    python3 scripts/vehicle_icons/build.py --preview  # also build/vehicle_icons/preview.png (light + dark cards)

Each render is a transparent PNG. The script trims it to the vehicle, paints a plain dark badge over a real car
maker's logo (the repo is public: no trademarks in the app), and saves a small WebP (alpha kept) for
`VehicleArt` in packages/tamiltaxi_ui. Renders that aren't listed here (van, MPV, luxury, roof-sign taxi) are kept
for tiers that may come later.
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'docs', 'design', 'vechile')
OUT = os.path.join(ROOT, 'packages', 'tamiltaxi_ui', 'assets', 'vehicles')

# Asset name (the VehicleKind's file) → (render, logos to cover as (centre x, centre y, rx, ry) in render px).
VEHICLES = {
    'bike': ('Modern White, Yellow, and Black Street Motorcycle.png', []),
    'scooty': ('White and Yellow Modern Scooter Cutout.png', []),
    'auto': ('Yellow-and-Black Tuk-Tuk Render.png', []),
    'auto_priority': ('Premium Yellow Electric Tuk-Tuk.png', []),
    'mini': ('White Compact Taxi Car Render.png', []),
    'sedan': ('White Sedan Taxi Cutout.png', [(1302, 584, 31, 27)]),
    'suv': ('White SUV Taxi with Yellow Stripe.png', []),
}

WIDTH = 360  # px; cards draw them at up to ~96 logical px wide, so this is enough for 3x screens


def cover_logo(im, cx, cy, rx, ry):
    """A plain dark badge in a thin chrome ring (like the other renders' blank badges), drawn 4x and scaled down."""
    k = 4
    pad = 4
    box = (cx - rx - pad, cy - ry - pad, cx + rx + pad, cy + ry + pad)
    w, h = box[2] - box[0], box[3] - box[1]
    layer = Image.new('RGBA', (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    o = pad * k
    d.ellipse((o, o, o + 2 * rx * k, o + 2 * ry * k), fill=(196, 200, 206, 255))
    t = 3 * k
    d.ellipse((o + t, o + t, o + 2 * rx * k - t, o + 2 * ry * k - t), fill=(26, 29, 34, 255))
    layer = layer.resize((w, h), Image.LANCZOS)
    im.alpha_composite(layer, (box[0], box[1]))


def build(name, render, logos):
    im = Image.open(os.path.join(SRC, render)).convert('RGBA')
    for logo in logos:
        cover_logo(im, *logo)
    bbox = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    im = im.crop(bbox)
    im = im.resize((WIDTH, round(im.height * WIDTH / im.width)), Image.LANCZOS)
    path = os.path.join(OUT, f'{name}.webp')
    im.save(path, 'WEBP', quality=88, method=6)
    return im, os.path.getsize(path)


def main():
    os.makedirs(OUT, exist_ok=True)
    built = {}
    for name, (render, logos) in VEHICLES.items():
        im, size = build(name, render, logos)
        built[name] = im
        print(f'{name}: {im.size[0]}x{im.size[1]}, {size // 1024} KB')
    if '--preview' in sys.argv:
        out = os.path.join(ROOT, 'build', 'vehicle_icons')
        os.makedirs(out, exist_ok=True)
        cw, ch = 400, 280
        sheet = Image.new('RGBA', (cw * len(built), ch * 2), (0, 0, 0, 255))
        for i, im in enumerate(built.values()):
            for j, bg in enumerate(((255, 241, 236, 255), (30, 41, 59, 255))):
                sheet.paste(Image.new('RGBA', (cw, ch), bg), (i * cw, j * ch))
                sheet.alpha_composite(im, (i * cw + (cw - im.width) // 2, j * ch + (ch - im.height) // 2))
        sheet.save(os.path.join(out, 'preview.png'))


if __name__ == '__main__':
    main()
