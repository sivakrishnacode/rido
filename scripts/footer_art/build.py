"""Builds the passenger home footer art (option A, "Namma Ooru"): a 360 x 308 line drawing of Tamil Nadu
for the bottom of the Ride sheet. The app draws "#NammaOoru" and "Made in Coimbatore" over the empty top.

    python3 scripts/footer_art/build.py

Writes packages/tamiltaxi_ui/assets/illustrations/home_footer.svg. Drawings live in elements.py.
"""
import os

from elements import (big_temple, bike_taxi, auto_rickshaw, clock_tower, coconut_palm, dancer, f, gopuram,
                      kolam_flower, mirror_x, nilgiri_train, pin, plough_team, pongal_pot, smooth, L)

W, H = 360, 308
SW = 1.25  # stroke width in dp
# The drawing is laid out on a 360 x 360 square; its top band is cropped so the art starts right under the
# app's two lines of text (HomeFooter uses the same 360:308 ratio).
CROP = 52

# TtColors: navy300 lines, inputBg fill; the top fades in from the white sheet.
BG = "#F1F5F9"
LINE = "#CBD5E1"
TOP = "#FFFFFF"

OUT = os.path.join(os.path.dirname(__file__), "../../packages/tamiltaxi_ui/assets/illustrations/home_footer.svg")


def place(draw, x, ground, s, gy, flip=False, w=None, **kw):
    """Stand an element whose local ground line is y=gy on `ground` at x, scaled by s (strokes stay SW wide)."""
    sw = SW / s
    frag = draw(sw, **kw)
    if flip:
        frag = mirror_x(frag, w)
    return f'<g transform="translate({f(x)},{f(ground - gy * s)}) scale({f(s)})" stroke-width="{f(sw)}">{frag}</g>'


def at(frag, x, y, s=1.0):
    return f'<g transform="translate({f(x)},{f(y)}) scale({f(s)})" stroke-width="{f(SW / s)}">{frag}</g>'


def dashed(d, dash):
    return f'<path d="{d}" fill="none" stroke-dasharray="{dash}"/>'


def namma_ooru():
    o = []
    # Back: hills, Thanjavur Big Temple, Nilgiri train, palms, Coimbatore clock tower, a gopuram, map pins.
    o.append(L(smooth([(0, 262), (40, 246), (80, 256), (130, 240), (190, 252), (250, 238), (310, 250), (360, 242)])))
    o.append(place(big_temple, 4, 258, 0.66, 150))
    o.append(place(nilgiri_train, 66, 246, 0.52, 40))
    o.append(place(coconut_palm, 138, 262, 0.66, 110))
    o.append(place(clock_tower, 240, 262, 0.64, 96))
    o.append(place(gopuram, 280, 264, 0.86, 140))
    o.append(place(coconut_palm, 192, 266, 0.58, 110, flip=True, w=90, lean=8, seed=4))
    o.append(at(pin(SW), 34, 236, 1.1))
    o.append(at(pin(SW), 334, 254, 0.95))
    # Middle: the road with a bike taxi and an auto.
    o.append(dashed(smooth([(0, 290), (70, 280), (150, 288), (230, 278), (300, 286), (360, 278)]), "6 6"))
    o.append(place(bike_taxi, 146, 290, 0.6, 46))
    o.append(place(auto_rickshaw, 242, 284, 0.64, 41))
    # Front: Pongal pot, Bharatanatyam dancer, flower kolam, farmer ploughing with Kangayam bulls.
    o.append(place(pongal_pot, 2, 352, 0.78, 70))
    o.append(place(dancer, 54, 354, 0.9, 120))
    o.append(at(kolam_flower(SW / 0.8, R=13), 170, 338, 0.8))
    o.append(place(plough_team, 192, 352, 0.72, 58))
    return "".join(o)


def svg():
    body = namma_ooru().replace("#LINE#", LINE).replace("#FILL#", BG).replace("#ACC#", LINE)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">'
            '<defs><linearGradient id="fade" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{TOP}"/><stop offset="0.22" stop-color="{BG}"/></linearGradient></defs>'
            f'<rect width="{W}" height="{H}" fill="url(#fade)"/>'
            f'<g transform="translate(0,-{CROP})" fill="{BG}" stroke="{LINE}" stroke-width="{SW}" '
            f'stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>\n')


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as fh:
        fh.write(svg())
    print(os.path.relpath(OUT), os.path.getsize(OUT), "bytes")
