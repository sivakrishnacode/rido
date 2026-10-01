"""Line-art drawings of Tamil Nadu for the Tamil Taxi home footer (used by build.py).

Every element is drawn at its natural size in local coordinates (y down, ground at the box bottom) and
returns an SVG fragment. Colours are tokens (#LINE#, #FILL#, #ACC#) replaced per palette. Shapes are
filled with the background colour and outlined, so later shapes hide earlier ones (painter's order).
"""
import math

def f(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s

def pt(p):
    return f"{f(p[0])},{f(p[1])}"

def poly(pts, closed=False):
    d = "M" + " L".join(pt(p) for p in pts)
    return d + (" Z" if closed else "")

def smooth(pts, closed=False):
    """Catmull-Rom spline through pts as cubic Beziers."""
    n = len(pts)
    if n < 3:
        return poly(pts, closed)
    d = "M" + pt(pts[0])
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if closed else pts[max(i - 1, 0)]
        p1 = pts[i]
        p2 = pts[(i + 1) % n] if closed else pts[i + 1]
        p3 = pts[(i + 2) % n] if closed else pts[min(i + 2, n - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C{pt(c1)} {pt(c2)} {pt(p2)}"
    return d + (" Z" if closed else "")

def O(d, extra=""):
    """Outlined shape filled with the background."""
    return f'<path d="{d}"{extra}/>'

def L(d, extra=""):
    """Line only."""
    return f'<path d="{d}" fill="none"{extra}/>'

def ACC(d):
    """Accent-coloured line (only some palettes give it a different colour)."""
    return f'<path d="{d}" fill="none" stroke="#ACC#"/>'

def dot(cx, cy, r):
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="#LINE#" stroke="none"/>'

def circ(cx, cy, r, filled=True):
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"' + ("" if filled else ' fill="none"') + "/>"

def limb(pts, w, sw, curve=False):
    """A limb of width w: a thick outline stroke with a background-coloured stroke inside."""
    d = smooth(pts) if curve else poly(pts)
    return (f'<path d="{d}" fill="none" stroke-width="{f(w + 2 * sw)}"/>'
            f'<path d="{d}" fill="none" stroke="#FILL#" stroke-width="{f(w)}"/>')

def rrect(x, y, w, h, r):
    return f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="{f(r)}"/>'

def qpt(p0, c, p2, t):
    return ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * p2[1])

def perp_tick(a, b, t, length):
    """Short line across segment a→b at fraction t (bangles, sugarcane joints)."""
    x = a[0] + (b[0] - a[0]) * t
    y = a[1] + (b[1] - a[1]) * t
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1
    px, py = -dy / n * length / 2, dx / n * length / 2
    return L(poly([(x - px, y - py), (x + px, y + py)]))

def mirror_x(frag, w):
    return f'<g transform="translate({f(w)},0) scale(-1,1)">{frag}</g>'

# ---------------------------------------------------------------- people

def dancer(sw):
    """Bharatanatyam dancer, front view: aramandi (half-sitting, knees out) with natyarambhe arms and the
    pleated fan between the knees. Box 100 x 120."""
    o = []
    # Arms (behind the torso): shoulder → raised elbow → wrist, palm (pataka) flat beyond the wrist.
    for s in (1, -1):
        X = lambda x: 50 + s * (x - 50)
        sh, el, wr, tip = (X(43), 37.5), (X(28), 33), (X(15), 35.5), (X(7.5), 32.5)
        o.append(limb([sh, el, wr], 4.4, sw))
        o.append(limb([wr, tip], 3.6, sw))
        o.append(perp_tick(el, wr, 0.62, 5.2))
        o.append(perp_tick(el, wr, 0.74, 5.2))
    # Legs in pyjama: hip → knee (out) → ankle (in).
    for s in (1, -1):
        X = lambda x: 50 + s * (x - 50)
        o.append(limb([(X(45.5), 67), (X(31.5), 88), (X(45), 107.5)], 10, sw))
    # Feet turned out, heels together, ankle bells.
    for s in (1, -1):
        X = lambda x: 50 + s * (x - 50)
        o.append(limb([(X(46.5), 115.5), (X(36.5), 118.6)], 4, sw))
        for i, (bx, by) in enumerate([(44.2, 112.4), (46.6, 113), (49, 113.3)]):
            o.append(circ(X(bx), by, 1.05))
    # Fan of pleats between the knees.
    apex, lft, ctl, rgt = (50, 68.5), (33.2, 90), (50, 113), (66.8, 90)
    o.append(O(f"M{pt(apex)} L{pt(lft)} Q{pt(ctl)} {pt(rgt)} Z"))
    inner = [qpt((36.5, 88.5), (50, 107.5), (63.5, 88.5), t) for t in (0, 0.5, 1)]
    o.append(L(f"M36.5,88.5 Q50,107.5 63.5,88.5"))
    for t in (0.18, 0.36, 0.5, 0.64, 0.82):
        x, y = qpt(lft, ctl, rgt, t)
        o.append(L(poly([(50, 71), (x, y)])))
    # Neck, torso, belt (oddiyanam), temple necklaces.
    o.append(rrect(47.3, 26, 5.4, 10, 1.5))
    o.append(O("M44.6,66.5 C43.4,56 40.4,46 41,39.2 Q41.6,35 45.2,34.6 L54.8,34.6 Q58.4,35 59,39.2 "
               "C59.6,46 56.6,56 55.4,66.5 Z"))
    o.append(rrect(43.6, 62.4, 12.8, 4.8, 2))
    o.append(circ(50, 64.8, 2.3))
    o.append(L("M45.2,35 Q50,43.5 54.8,35"))
    o.append(L("M43.6,35.6 Q50,53 56.4,35.6"))
    o.append(circ(50, 44.4, 1.7))
    # Head, hair with centre parting, surya-chandra ornaments, nethi chutti, bindi, jimikki earrings.
    for s in (1, -1):
        X = lambda x: 50 + s * (x - 50)
        o.append(O(f"M{f(X(41.7))},29.2 Q{f(X(43.4))},25.6 {f(X(45.1))},29.2 Z"))
    o.append(circ(50, 21.5, 6.6))
    o.append(O("M43.3,23.6 C42.8,16.2 46,14.2 50,14.2 C54,14.2 57.2,16.2 56.7,23.6 "
               "C55.6,19.6 53.2,18.4 50,18.4 C46.8,18.4 44.4,19.6 43.3,23.6 Z"))
    o.append(L("M50,14.4 L50,18.2"))
    o.append(circ(46.4, 16.6, 1.25))
    o.append(circ(53.6, 16.6, 1.25))
    o.append(dot(50, 19.6, 0.95))
    o.append(dot(50, 22.6, 0.7))
    return "".join(o)


def farmer(sw):
    """Farmer walking right behind a plough: turban, towel on the shoulder, veshti tucked to the knees,
    a stick in the back hand. The front hand is at (28, 27). Box 32 x 60."""
    o = []
    # Back arm with stick.
    o.append(L("M10.2,31 L1.5,3.5"))
    o.append(limb([(13.2, 17.6), (10.4, 24.6), (9, 29.6)], 3.2, sw))
    # Legs (walking): back leg, front leg, feet.
    o.append(limb([(13.6, 43), (11.4, 51.5), (8.6, 58.6)], 3.4, sw))
    o.append(limb([(18.6, 43), (21.6, 51.5), (23.8, 58.6)], 3.4, sw))
    o.append(limb([(8.2, 59.3), (11.6, 59.6)], 2.4, sw))
    o.append(limb([(23.6, 59.3), (27.2, 59.6)], 2.4, sw))
    # Neck, torso (leaning forward a little), veshti.
    o.append(rrect(14.4, 11.5, 4.2, 5.5, 1.2))
    o.append(O("M11.6,17.2 Q12.6,14.6 16.4,14.4 Q20.6,14.6 21.4,17.6 L20.6,31.5 L12.6,31.5 Z"))
    o.append(O("M12.2,30.4 L20.8,30.4 L23,44 Q16.4,45.6 9.8,44 Z"))
    o.append(L("M12.4,33 Q16.6,34.2 20.8,32.8"))
    o.append(L("M19.4,33.6 L20.6,43.6"))
    # Towel over the shoulder.
    o.append(L("M12.6,16.4 Q15.6,19.6 19.6,25.8"))
    # Front arm to the plough handle.
    o.append(limb([(19.6, 17.8), (23.4, 23.8), (28, 27)], 3.2, sw))
    # Head and turban (mundasu) with the knot's tail at the back.
    o.append(circ(17.2, 8.6, 4.4))
    o.append(O("M11.9,8.4 C11.6,4.2 14.4,2.4 17.6,2.6 C20.8,2.8 22.6,4.6 22.4,7.6 L21.4,8.2 "
               "C19.2,6.8 15,6.8 12.6,9.2 Z"))
    o.append(O("M12.4,6.2 L8.6,8.4 L11.6,9.6 Z"))
    return "".join(o)


def karagattam(sw):
    """Karagattam dancer balancing the decorated karagam pot tower on her head. Box 60 x 118."""
    o = []
    # Raised arms (one up, one out), legs in a step.
    o.append(limb([(26, 52), (16, 46), (10, 37)], 4, sw))
    o.append(limb([(10, 37), (8, 31.5)], 3.3, sw))
    o.append(limb([(34, 52), (44, 54), (52, 49)], 4, sw))
    o.append(limb([(52, 49), (56.5, 45.5)], 3.3, sw))
    o.append(limb([(27.6, 92), (24, 104), (22, 115)], 4.2, sw))
    o.append(limb([(32.4, 92), (37.4, 102), (37, 113)], 4.2, sw))
    o.append(limb([(21.6, 116.4), (16.8, 117.6)], 3, sw))
    o.append(limb([(37.6, 114.8), (42.6, 116.6)], 3, sw))
    # Skirt (pavadai) flaring with a border.
    o.append(O("M24.6,72 L35.4,72 L44,96 Q30,101 16,96 Z"))
    o.append(L("M17.6,92 Q30,97 42.4,92"))
    # Torso, neck.
    o.append(rrect(27.6, 42, 4.8, 8, 1.4))
    o.append(O("M25,73 C24.2,64 22.8,56 23.6,52.2 Q24.4,48.6 27.6,48.4 L32.4,48.4 Q35.6,48.6 36.4,52.2 "
               "C37.2,56 35.8,64 35,73 Z"))
    o.append(L("M25.6,70 L34.4,70"))
    # Head and the karagam: pot, then a tapering flower tower with a parrot-like finial.
    o.append(circ(30, 37, 5.8))
    o.append(O("M25.2,33.2 C24.8,29.6 27,28.4 30,28.4 C33,28.4 35.2,29.6 34.8,33.2 C33.4,31.6 26.6,31.6 25.2,33.2 Z"))
    o.append(O("M22.6,22.4 C22.6,27.6 26,29.6 30,29.6 C34,29.6 37.4,27.6 37.4,22.4 C37.4,19.2 34,18.2 30,18.2 "
               "C26,18.2 22.6,19.2 22.6,22.4 Z"))
    o.append(L("M23.4,23.2 Q30,26 36.6,23.2"))
    o.append(O("M25.6,18.6 L28.2,3.8 L31.8,3.8 L34.4,18.6 Z"))
    for y in (8, 12, 16):
        o.append(L(f"M{f(28.4 - (y - 4) * 0.19)},{f(y)} L{f(31.6 + (y - 4) * 0.19)},{f(y)}"))
    o.append(circ(30, 2.6, 1.8))
    return "".join(o)


def parai_drummer(sw):
    """Parai drummer: frame drum on a strap at the left side, two sticks. Box 52 x 100, facing right."""
    o = []
    o.append(limb([(20.6, 62), (18, 78), (15, 97)], 4, sw))
    o.append(limb([(27.4, 62), (31, 78), (34, 97)], 4, sw))
    o.append(limb([(14.4, 98.2), (10, 99.4)], 3, sw))
    o.append(limb([(34.6, 98.2), (39, 99.4)], 3, sw))
    o.append(O("M18.6,48 L29.6,48 L33,66 Q24,68.6 15.4,66 Z"))
    o.append(L("M19.2,51 Q24,52.2 29,50.8"))
    o.append(rrect(21.6, 18, 4.8, 7, 1.4))
    o.append(O("M17.4,25.8 Q18,23.2 24,23 Q30,23.2 30.8,26 L29.6,49 L18.8,49 Z"))
    # Strap and drum (seen at an angle, an ellipse) on the left, sticks.
    o.append(L("M19,25 L36.6,47"))
    o.append(f'<ellipse cx="38.4" cy="41" rx="7.4" ry="13.6" transform="rotate(-16 38.4 41)"/>')
    o.append(f'<ellipse cx="38.4" cy="41" rx="4.9" ry="11" fill="none" transform="rotate(-16 38.4 41)"/>')
    o.append(limb([(29, 27.6), (35, 33), (40.4, 31)], 3.4, sw))
    o.append(L("M40.4,31 L49.6,21.6"))
    o.append(limb([(19, 27.6), (17.4, 37), (27, 40)], 3.4, sw))
    o.append(L("M27,40 L31.6,47.4"))
    o.append(circ(24, 14.6, 4.6))
    o.append(O("M19.4,13.4 C19.6,10.2 21.6,9.6 24,9.6 C26.6,9.6 28.6,10.4 28.6,13.4 Z"))
    o.append(L("M19.2,12 Q24,10.6 28.8,12"))
    return "".join(o)


def silambam(sw):
    """Silambam fighter in a lunge, staff held across the body. Box 80 x 100, facing right."""
    o = []
    o.append(limb([(36, 62), (24, 76), (14, 97)], 4.2, sw))
    o.append(limb([(42, 62), (54, 74), (55, 97)], 4.2, sw))
    o.append(limb([(13.4, 98.4), (8.4, 99.2)], 3, sw))
    o.append(limb([(55.6, 98.2), (60.6, 99.4)], 3, sw))
    o.append(O("M34.6,48 L44.8,48 L50,70 Q40,73 30,70 Z"))
    o.append(L("M35,51 Q40,52.4 44.6,50.8"))
    o.append(rrect(37, 19, 4.8, 7, 1.4))
    o.append(O("M33.4,26.8 Q34,24 39.4,23.8 Q45.6,24 46.4,27 L45,49 L34.6,49 Z"))
    # Staff (long, diagonal), arms holding it.
    o.append(limb([(2, 72), (78, 4)], 2.4, sw))
    o.append(limb([(44.6, 28), (52, 33), (56.6, 25.4)], 3.4, sw))
    o.append(limb([(34.6, 28.4), (30, 40), (33.6, 47.4)], 3.4, sw))
    o.append(circ(39.4, 15.4, 4.6))
    o.append(L("M34.8,13.4 Q39.4,11.6 44,13.4"))
    o.append(L("M34.8,13.4 L31.4,15.6"))
    return "".join(o)


def bike_taxi(sw):
    """Motorbike taxi with a helmeted rider and pillion, facing right. Box 60 x 46."""
    o = []
    # Wheels.
    for cx in (11, 48):
        o.append(circ(cx, 38.4, 7.2))
        o.append(circ(cx, 38.4, 2.2))
    # Body: rear fender, seat, tank, engine, fork, handlebar, headlamp.
    o.append(O("M6.6,31 C8.6,27.8 13.4,27 17,29 L36,29 C38,26 41.4,24.6 44,25 L45.6,30.6 L40,36.6 L18.6,36.6 Z"))
    o.append(L("M44.4,25.6 L48,38.4"))
    o.append(L("M42.6,20.4 L44.8,26"))
    o.append(L("M40.2,20.6 L45,19.6"))
    o.append(circ(46.6, 27.4, 1.6))
    o.append(rrect(21, 33.6, 12, 6.4, 1.6))
    # Pillion (behind), then rider.
    o.append(limb([(15.6, 27.4), (18.4, 32.6), (15, 37.8)], 3.4, sw))
    o.append(O("M10.6,27.4 L12.6,14.6 Q13.6,12 16.6,12.4 Q19.6,13.2 19.4,16 L18.4,28 Z"))
    o.append(limb([(18, 16.8), (22.6, 21.6), (26.6, 21)], 3, sw))
    o.append(circ(15.8, 8.2, 4.8))
    o.append(L("M15.4,6.2 L20.4,6.6 L20.4,9.8"))
    o.append(limb([(25.4, 27.4), (31, 29.6), (30, 36.8)], 3.6, sw))
    o.append(O("M20.6,27.6 L24.6,14.4 Q26,11.8 29,12.6 Q32,13.6 31.4,16.4 L27.6,28.4 Z"))
    o.append(limb([(29.6, 16.4), (36, 20.6), (41, 20.4)], 3, sw))
    o.append(circ(29.6, 7.8, 5))
    o.append(L("M29.4,5.6 L34.6,6.2 L34.4,9.6"))
    return "".join(o)


def auto_rickshaw(sw):
    """Auto rickshaw, side view facing right, with a driver. Box 56 x 42."""
    o = []
    o.append(O("M5,14 C5,8.4 8.6,5.4 15,5.4 L37.4,5.4 C41.6,5.4 44,7.6 45.2,11 L48.6,22 "
               "C51.8,23.2 53.4,25.6 53.4,28 L53.4,31.2 L5,31.2 Z"))
    # Open passenger side with seat; driver opening with the driver.
    o.append(O("M9.4,24.6 L9.4,14.4 C9.4,11.2 11,10 14,10 L27.6,10 L27.6,24.6 Z"))
    o.append(L("M12.4,24.4 L12.4,17.4 Q12.4,15.6 14.4,15.6 L17,15.6"))
    o.append(O("M31,22.6 L31,10 L41.6,10 L44.6,22.6 Z"))
    o.append(circ(35.6, 14.2, 2.6))
    o.append(L("M33.4,22.4 L34.6,17.6 L38.6,17.6"))
    o.append(L("M5,27.4 L51,27.4"))
    o.append(circ(51.2, 24.2, 1.4))
    for cx in (14.6, 46.4):
        o.append(circ(cx, 34.4, 6.4))
        o.append(circ(cx, 34.4, 2))
    return "".join(o)

# ---------------------------------------------------------------- places

def gopuram(sw, tiers=5):
    """Dravidian temple tower: masonry base with a doorway, tapering tiers with cornices, a central
    window line and kudu niches, a barrel-vault (shala) top with kalasam finials. Box 80 x 140."""
    o = []
    base_top, top_y = 108, 30
    lx = lambda y: 9 + (base_top - y) * (13 / (base_top - top_y))
    # Base block with doorway.
    o.append(O("M7,140 L7,111 L73,111 L73,140 Z"))
    o.append(L("M5,140 L75,140"))
    o.append(L("M7,124 L73,124"))
    o.append(O("M33.4,140 L33.4,122 Q40,115.4 46.6,122 L46.6,140 Z"))
    o.append(L("M5.4,111 L74.6,111"))
    # Tiers.
    h = (base_top - top_y) / tiers
    o.append(O(f"M{f(lx(base_top))},{f(base_top)} L{f(lx(top_y))},{f(top_y)} "
               f"L{f(80 - lx(top_y))},{f(top_y)} L{f(80 - lx(base_top))},{f(base_top)} Z"))
    for i in range(tiers):
        yb = base_top - i * h
        yt = yb - h
        x0, x1 = lx(yb), 80 - lx(yb)
        o.append(L(f"M{f(x0 - 2.4)},{f(yb)} L{f(x1 + 2.4)},{f(yb)}"))
        o.append(L(f"M{f(x0 - 1.2)},{f(yb - 2.4)} L{f(x1 + 1.2)},{f(yb - 2.4)}"))
        # Central window.
        o.append(O(f"M37.6,{f(yb - 3.6)} L37.6,{f(yt + 5.2)} Q40,{f(yt + 2.4)} 42.4,{f(yt + 5.2)} "
                   f"L42.4,{f(yb - 3.6)} Z"))
        # Kudu niches either side, fewer as the tower narrows.
        n = max(1, 3 - i // 2)
        span = (x1 - x0) / 2 - 6
        for k in range(n):
            dx = 6 + (k + 0.5) * (span - 2) / n
            for s in (-1, 1):
                cx = 40 + s * dx
                o.append(L(f"M{f(cx - 1.5)},{f(yb - 3.6)} L{f(cx - 1.5)},{f(yt + 4.6)} "
                           f"Q{f(cx)},{f(yt + 2.6)} {f(cx + 1.5)},{f(yt + 4.6)} L{f(cx + 1.5)},{f(yb - 3.6)}"))
    # Shala roof and kalasams.
    o.append(L(f"M{f(lx(top_y) - 2.6)},{f(top_y)} L{f(80 - lx(top_y) + 2.6)},{f(top_y)}"))
    o.append(O("M21,30 L21,22.6 Q21,14.6 30,14.6 L50,14.6 Q59,14.6 59,22.6 L59,30 Z"))
    o.append(L("M18,24 Q19,19.6 21.6,19.2"))
    o.append(L("M62,24 Q61,19.6 58.4,19.2"))
    o.append(O("M34,30 L34,24.6 Q40,19 46,24.6 L46,30 Z"))
    for x in (27, 33.5, 40, 46.5, 53):
        o.append(L(f"M{f(x)},14.6 L{f(x)},9.6"))
        o.append(circ(x, 8.4, 1.6))
        o.append(L(f"M{f(x)},6.8 L{f(x)},4"))
    return "".join(o)


def clock_tower(sw):
    """Coimbatore Town Hall clock tower (Manikoondu): square shaft with pointed arches, clock stage,
    small dome with a finial. Box 32 x 96."""
    o = []
    o.append(O("M5,96 L5,86 L27,86 L27,96 Z"))
    o.append(L("M3,96 L29,96"))
    o.append(O("M8.6,86 L8.6,34 L23.4,34 L23.4,86 Z"))
    for y in (62, 46):
        o.append(O(f"M12.4,{f(y + 14)} L12.4,{f(y + 4)} Q16,{f(y - 2.6)} 19.6,{f(y + 4)} L19.6,{f(y + 14)} Z"))
    o.append(O("M12.4,85.8 L12.4,80.8 Q16,76 19.6,80.8 L19.6,85.8 Z"))
    o.append(L("M7.2,34 L24.8,34"))
    o.append(O("M7.4,34 L7.4,15.4 L24.6,15.4 L24.6,34 Z"))
    o.append(circ(16, 24.6, 5.2))
    o.append(L("M16,24.6 L16,21.4 M16,24.6 L18.4,25.8"))
    o.append(L("M5.6,15.4 L26.4,15.4"))
    o.append(O("M8.4,15.4 Q8.6,7.4 16,6.4 Q23.4,7.4 23.6,15.4 Z"))
    o.append(L("M16,6.4 L16,1.4"))
    o.append(circ(16, 3.4, 1.1))
    return "".join(o)


def ridges(sw, w, h, seed=0):
    """Two layers of Western Ghats ridges, outline only."""
    import random
    rnd = random.Random(seed)
    o = []
    for layer, (amp, base) in enumerate(((h * 0.8, h), (h * 0.5, h))):
        pts = [(0, base - amp * 0.3)]
        x = 0
        while x < w:
            x += rnd.uniform(w * 0.08, w * 0.16)
            pts.append((min(x, w), base - amp * rnd.uniform(0.35, 1.0)))
        pts.append((w, base - amp * 0.3))
        o.append(L(smooth(pts)))
    return "".join(o)


def nilgiri_train(sw):
    """Nilgiri Mountain Railway: little steam engine (chimney at the front) and two coaches on a track.
    Box 160 x 44, faces right."""
    o = []
    gy = 40
    # Track with sleepers.
    o.append(L(f"M0,{f(gy)} L160,{f(gy)}"))
    for x in range(4, 160, 7):
        o.append(L(f"M{f(x)},{f(gy)} L{f(x - 2.4)},{f(gy + 3.6)}"))
    # Coaches.
    for cx0 in (2, 50):
        o.append(O(f"M{f(cx0)},{f(gy - 5)} L{f(cx0)},{f(gy - 23)} Q{f(cx0)},{f(gy - 27)} {f(cx0 + 5)},{f(gy - 27.6)} "
                   f"L{f(cx0 + 39)},{f(gy - 27.6)} Q{f(cx0 + 44)},{f(gy - 27)} {f(cx0 + 44)},{f(gy - 23)} L{f(cx0 + 44)},{f(gy - 5)} Z"))
        o.append(L(f"M{f(cx0 - 1)},{f(gy - 24)} L{f(cx0 + 45)},{f(gy - 24)}"))
        for k in range(4):
            wx = cx0 + 4.6 + k * 9.4
            o.append(rrect(wx, gy - 20.4, 6.4, 7.4, 1.2))
        o.append(L(f"M{f(cx0)},{f(gy - 9)} L{f(cx0 + 44)},{f(gy - 9)}"))
        for wx in (cx0 + 9, cx0 + 35):
            o.append(circ(wx, gy - 3.2, 3.2))
    o.append(L(f"M46,{f(gy - 7)} L50,{f(gy - 7)} M94,{f(gy - 7)} L99,{f(gy - 7)}"))
    # Engine: cab, boiler, chimney, dome, wheels, cowcatcher.
    o.append(O(f"M99,{f(gy - 5)} L99,{f(gy - 30)} L117,{f(gy - 30)} L117,{f(gy - 5)} Z"))
    o.append(L(f"M97,{f(gy - 30.4)} Q108,{f(gy - 34)} 119,{f(gy - 30.4)}"))
    o.append(rrect(102, gy - 26, 9, 8, 1.2))
    o.append(O(f"M117,{f(gy - 9)} L117,{f(gy - 22)} L148,{f(gy - 22)} Q152,{f(gy - 22)} 152,{f(gy - 17)} "
               f"L152,{f(gy - 9)} Z"))
    o.append(L(f"M117,{f(gy - 15.6)} L152,{f(gy - 15.6)}"))
    o.append(O(f"M141,{f(gy - 22)} L141.6,{f(gy - 31)} L139.6,{f(gy - 33.4)} L148.4,{f(gy - 33.4)} "
               f"L146.4,{f(gy - 31)} L147,{f(gy - 22)} Z"))
    o.append(O(f"M125,{f(gy - 22)} Q125,{f(gy - 27.6)} 129.6,{f(gy - 27.6)} Q134.2,{f(gy - 27.6)} 134.2,{f(gy - 22)} Z"))
    o.append(O(f"M152,{f(gy - 9)} L158,{f(gy - 1.4)} L148,{f(gy - 1.4)} Z"))
    for wx in (106, 124, 136):
        o.append(circ(wx, gy - 4.4, 4.4))
        o.append(circ(wx, gy - 4.4, 1.1))
    o.append(L(f"M106,{f(gy - 4.4)} L136,{f(gy - 4.4)}"))
    # Steam puffs.
    for cx, cy, r in ((146, gy - 38.6, 3.4), (139.6, gy - 41.6, 4.2), (131, gy - 42, 3.2)):
        o.append(circ(cx, cy, r))
    return "".join(o)


def pongal_pot(sw):
    """Pongal: clay pot boiling over on a three-stone hearth, turmeric leaves at the neck, sugarcane
    crossed behind. Box 64 x 70."""
    o = []
    # Sugarcane, crossed behind.
    for a, b in (((12, 70), (4, 6)), ((52, 70), (60, 6))):
        o.append(limb([a, b], 3.6, sw))
        for t in (0.16, 0.32, 0.48, 0.64, 0.8):
            o.append(perp_tick(a, b, t, 3.6))
        tx, ty = b
        s = -1 if tx < 32 else 1
        o.append(L(f"M{f(tx)},{f(ty + 2)} Q{f(tx + s * 10)},{f(ty - 6)} {f(tx + s * 18)},{f(ty + 2)}"))
        o.append(L(f"M{f(tx)},{f(ty + 2)} Q{f(tx - s * 6)},{f(ty - 6)} {f(tx - s * 12)},{f(ty - 2)}"))
        o.append(L(f"M{f(tx)},{f(ty + 2)} Q{f(tx + s * 4)},{f(ty - 8)} {f(tx + s * 3)},{f(ty - 14)}"))
    # Hearth stones and flames.
    for x in (13, 41):
        o.append(O(f"M{f(x)},70 L{f(x)},62 Q{f(x)},59 {f(x + 3)},59 L{f(x + 7)},59 Q{f(x + 10)},59 {f(x + 10)},62 L{f(x + 10)},70 Z"))
    for x, hgt in ((26, 9), (32, 11.4), (38, 8.4)):
        o.append(O(f"M{f(x)},70 C{f(x - 3.2)},68 {f(x - 2.4)},{f(70 - hgt * 0.6)} {f(x)},{f(70 - hgt)} "
                   f"C{f(x + 2.4)},{f(70 - hgt * 0.6)} {f(x + 3.2)},68 {f(x)},70 Z"))
    o.append(L("M8,70 L56,70"))
    # Pot body, neck, rim, decoration.
    o.append(O("M32,62.4 C20.6,62.4 15.4,55.4 15.4,47 C15.4,38.6 21,33.6 25.6,32 L38.4,32 C43,33.6 48.6,38.6 48.6,47 "
               "C48.6,55.4 43.4,62.4 32,62.4 Z"))
    o.append(L("M17.2,44 Q32,48.6 46.8,44"))
    for x in (21.6, 26.8, 32, 37.2, 42.4):
        o.append(dot(x, 47.6 + (0.4 if x in (26.8, 37.2) else 1.2 if x == 32 else -0.4), 0.9))
    o.append(O("M24.4,32.4 L25,28 L39,28 L39.6,32.4 Z"))
    # Turmeric leaves tied at the neck.
    o.append(O("M25.4,30 C19,28 15.6,22.6 15.4,16.6 C19.6,19.6 23.8,24 25.4,30 Z"))
    o.append(O("M38.6,30 C45,28 48.4,22.6 48.6,16.6 C44.4,19.6 40.2,24 38.6,30 Z"))
    o.append(rrect(21.6, 25, 20.8, 3.4, 1.6))
    # Foam boiling over, drips.
    o.append(O("M22.4,25.6 C20.4,24.6 20.6,21.6 23,21 C23,17.6 27,16.4 29,18.4 C30.4,15.6 34.6,15.6 35.8,18.6 "
               "C38.2,16.8 42,18.4 41.2,21.6 C43.6,22.4 43.2,25.2 41.4,25.6 Z"))
    o.append(L("M23.6,27.6 C22.8,30.6 23.8,33.4 22.6,36.2"))
    o.append(L("M40.6,27.6 C41.2,30 40.2,32 41.6,34.4"))
    return "".join(o)


def thoranam(sw, w=360, sag=6, step=13):
    """Mango-leaf thoranam strung across the top, marigolds between the leaves."""
    o = []
    o.append(L(f"M0,2 Q{f(w / 2)},{f(2 + sag * 2)} {f(w)},2"))
    x = step / 2
    k = 0
    while x < w:
        y = qpt((0, 2), (w / 2, 2 + sag * 2), (w, 2), x / w)[1]
        if k % 2 == 0:
            o.append(O(f"M{f(x)},{f(y)} C{f(x - 4.4)},{f(y + 5)} {f(x - 3)},{f(y + 13)} {f(x)},{f(y + 17)} "
                       f"C{f(x + 3)},{f(y + 13)} {f(x + 4.4)},{f(y + 5)} {f(x)},{f(y)} Z"))
            o.append(L(f"M{f(x)},{f(y + 1)} L{f(x)},{f(y + 14)}"))
        else:
            o.append(circ(x, y + 3, 2.6))
            o.append(circ(x, y + 3, 1))
        x += step / 2
        k += 1
    return "".join(o)


def kuthuvilakku(sw):
    """Brass oil lamp (kuthuvilakku): domed base, ringed stem, five-wick bowl, finial. Box 30 x 70."""
    o = []
    o.append(O("M3,70 Q3,62 15,60.4 Q27,62 27,70 Z"))
    o.append(L("M1,70 L29,70"))
    o.append(O("M13,60.6 L13,30 L17,30 L17,60.6 Z"))
    for y in (36, 44, 52):
        o.append(O(f"M11.4,{f(y)} L18.6,{f(y)} L18.6,{f(y + 2.4)} L11.4,{f(y + 2.4)} Z"))
    o.append(O("M3.4,26 Q15,36 26.6,26 Z"))
    for x in (5.4, 10.2, 15, 19.8, 24.6):
        o.append(O(f"M{f(x)},26 C{f(x - 1.8)},24 {f(x - 1)},21.4 {f(x)},19.6 C{f(x + 1)},21.4 {f(x + 1.8)},24 {f(x)},26 Z"))
    o.append(O("M13.6,24 L13.6,12 L16.4,12 L16.4,24 Z"))
    o.append(O("M15,3 L18.4,8.4 L15,12.4 L11.6,8.4 Z"))
    return "".join(o)


def pin(sw, r=6):
    """Map pin."""
    return (O(f"M{f(r)},{f(r * 2.7)} C{f(r * 0.4)},{f(r * 1.9)} 0,{f(r * 1.5)} 0,{f(r)} "
              f"A{f(r)},{f(r)} 0 1 1 {f(2 * r)},{f(r)} C{f(2 * r)},{f(r * 1.5)} {f(r * 1.6)},{f(r * 1.9)} {f(r)},{f(r * 2.7)} Z")
            + circ(r, r, r * 0.38))


def jasmine(sw, w=40):
    """A string of jasmine buds."""
    o = [L(f"M0,0 Q{f(w / 2)},6 {f(w)},0")]
    for i in range(1, 9):
        t = i / 9
        x, y = qpt((0, 0), (w / 2, 6), (w, 0), t)
        o.append(O(f"M{f(x)},{f(y)} C{f(x - 1.8)},{f(y + 1.6)} {f(x - 1)},{f(y + 4)} {f(x)},{f(y + 5)} "
                   f"C{f(x + 1)},{f(y + 4)} {f(x + 1.8)},{f(y + 1.6)} {f(x)},{f(y)} Z"))
    return "".join(o)


def textile_mill(sw, w=70):
    """Sawtooth-roof textile mill with a chimney ('Manchester of South India'). Box w x 50."""
    o = []
    o.append(O(f"M{f(w - 14)},50 L{f(w - 12.6)},4 L{f(w - 7.4)},4 L{f(w - 6)},50 Z"))
    o.append(L(f"M{f(w - 13)},10 L{f(w - 7)},10"))
    teeth = 4
    tw = (w - 16) / teeth
    d = "M0,50 L0,30"
    for i in range(teeth):
        x = i * tw
        d += f" L{f(x)},18 L{f(x + tw)},30"
    d += f" L{f(w - 16)},50 Z"
    o.append(O(d))
    for i in range(teeth):
        x = i * tw
        o.append(L(f"M{f(x + 1.2)},21 L{f(x + 1.2)},29"))
    for k in range(4):
        o.append(rrect(4 + k * (w - 24) / 4, 36, 6, 8, 1))
    return "".join(o)


def kangayam_bull(sw, decorated=False):
    """Kangayam bull (Kongu breed), side view facing right: long barrel, high hump, long head, backswept
    horns, dewlap. decorated=True adds painted horn bands, a neck bell and a back cloth (Mattu Pongal).
    Box 70 x 46."""
    o = []
    # Far horn, far legs, tail.
    o.append(O("M57.6,12.4 C58,8 57.4,5 55.4,2.2 C59,4.2 60.8,8 60.2,12.4 Z"))
    for p in ([(21.6, 32), (21.6, 45.4)], [(45.6, 32), (46.6, 45.4)]):
        o.append(limb(p, 3.2, sw))
    o.append(L("M12.6,17 C8.6,20 8.2,28 9,37.6"))
    o.append(O("M9,36.8 C7.2,39 7.6,41.8 9.2,43 C10.6,41.6 10.6,39 9,36.8 Z"))
    for p in ([(17, 32), (15.4, 38.4), (17.2, 45.4)], [(41, 32), (41.4, 45.4)]):
        o.append(limb(p, 3.4, sw))
    # Body with hump and dewlap.
    o.append(O("M12,19 C12,15.6 14.4,14 18.4,14 L34,14 C35,9 38.4,6 42,6 C45,6 46.4,8.6 47.2,11.6 "
               "C50.4,12.6 53,13 55.4,14.4 L55.6,24.4 C52.4,28 49.4,31.4 47.4,34.2 C46.2,35.8 44.2,36 42,35.2 "
               "L18.4,35.2 C14.4,35 12,32 12,28 Z"))
    o.append(L("M20.6,35 C22,31 22.4,26 21.2,22"))
    # Head, near horn, ear, eye.
    o.append(O("M54,12.4 C57,11 60,13 61.2,16 L64.8,25 C65.6,27.6 63.6,29.8 61.2,29.2 L56.8,27.6 "
               "C54.4,26.6 53,23.2 52.6,19 Z"))
    o.append(O("M55,12.8 C54.2,8.2 52,5 48.4,2.6 C53.2,3.6 57,7.4 57.6,12.2 Z"))
    o.append(O("M60.4,16.4 C63,15.8 65.8,16.4 67.2,17.4 C65.4,18.8 62.6,18.8 60.8,18.2 Z"))
    o.append(dot(58.4, 18.2, 0.8))
    if decorated:
        o.append(L("M52.4,6.8 L54.4,5.4 M54,9.6 L56.2,8.4"))
        o.append(O("M24,14.2 L40,14.2 L41,26 Q32,28.4 23.2,26 Z"))
        o.append(L("M23.6,22.6 Q32,25 40.6,22.6"))
        o.append(L("M53,25.4 Q50.6,29.6 47.6,31.6"))
        o.append(O("M49,30.6 L52.6,30.6 L53.2,34.4 L48.4,34.4 Z"))
    return "".join(o)


def paddy(sw, w=60, rows=3, seed=3):
    """Rows of young paddy: tufts of 4 blades."""
    import random
    rnd = random.Random(seed)
    o = []
    for r in range(rows):
        y = r * 7
        x = rnd.uniform(0, 4) + r * 3
        while x < w:
            h = rnd.uniform(6.4, 8)
            o.append(L(f"M{f(x)},{f(y)} Q{f(x - 0.6)},{f(y - h * 0.6)} {f(x - 3.4)},{f(y - h * 0.9)} "
                       f"M{f(x)},{f(y)} Q{f(x - 0.2)},{f(y - h * 0.7)} {f(x - 1)},{f(y - h * 1.12)} "
                       f"M{f(x)},{f(y)} Q{f(x + 0.4)},{f(y - h * 0.7)} {f(x + 1.4)},{f(y - h)} "
                       f"M{f(x)},{f(y)} Q{f(x + 0.8)},{f(y - h * 0.5)} {f(x + 3.6)},{f(y - h * 0.72)}"))
            x += rnd.uniform(7.4, 9.4)
    return "".join(o)


def coconut_palm(sw, h=110, lean=10, seed=1, flip=False):
    """Coconut palm: curved ringed trunk, long drooping fronds, a cluster of nuts. Box ~90 x h, trunk base x=45."""
    o = []
    bx, by = 45, h
    top = (45 + lean, 26)
    ctrl = (45 - lean * 0.6, h * 0.55)
    left = [qpt((bx - 3, by), (ctrl[0] - 2.6, ctrl[1]), (top[0] - 1.8, top[1]), t / 10) for t in range(11)]
    right = [qpt((bx + 3, by), (ctrl[0] + 2.6, ctrl[1]), (top[0] + 1.8, top[1]), t / 10) for t in range(11)]
    o.append(O(poly(left + right[::-1], closed=True)))
    for t in [i / 13 for i in range(1, 13)]:
        a = qpt((bx - 3, by), (ctrl[0] - 2.6, ctrl[1]), (top[0] - 1.8, top[1]), t)
        b = qpt((bx + 3, by), (ctrl[0] + 2.6, ctrl[1]), (top[0] + 1.8, top[1]), t)
        o.append(L(f"M{pt(a)} Q{f((a[0] + b[0]) / 2)},{f(a[1] + 1.4)} {pt(b)}"))
    fronds = [(250, 22, 6), (290, 22, 6), (225, 30, 13), (315, 30, 13), (200, 37, 20), (340, 37, 20),
              (178, 34, 24), (2, 34, 24)]
    for a, Ln, droop in fronds:
        r = math.radians(a)
        dx, dy = math.cos(r), math.sin(r)
        c = (top[0] + dx * Ln * 0.6, top[1] + dy * Ln * 0.6 - Ln * 0.16)
        tip = (top[0] + dx * Ln, top[1] + dy * Ln + droop)
        o.append(L(f"M{pt(top)} Q{pt(c)} {pt(tip)}"))
        n = 9
        for i in range(2, n + 1):
            t = i / (n + 0.6)
            p = qpt(top, c, tip, t)
            q = qpt(top, c, tip, min(t + 0.02, 1))
            tx, ty = q[0] - p[0], q[1] - p[1]
            m = math.hypot(tx, ty) or 1
            tx, ty = tx / m, ty / m
            ln = 9 * (1 - t * 0.5)
            for s in (1, -1):
                ang = math.radians(30 * s)
                vx = tx * math.cos(ang) - ty * math.sin(ang)
                vy = tx * math.sin(ang) + ty * math.cos(ang) + 0.9
                mm = math.hypot(vx, vy)
                o.append(L(f"M{pt(p)} Q{f(p[0] + vx / mm * ln * 0.5)},{f(p[1] + vy / mm * ln * 0.42)} "
                           f"{f(p[0] + vx / mm * ln)},{f(p[1] + vy / mm * ln)}"))
    for dx, dy in ((-3, 4.6), (2.8, 5), (-0.1, 7.8)):
        o.append(circ(top[0] + dx, top[1] + dy, 2.6))
    frag = "".join(o)
    return mirror_x(frag, 90) if flip else frag


def hill_temple(sw, w=150, h=58):
    """Hill temple (Marudhamalai / Palani style): a hill, a small temple on top, steps winding up."""
    o = []
    ridge = [(0, h), (w * 0.14, h - 14), (w * 0.3, h - 30), (w * 0.44, h - 40), (w * 0.56, h - 40.4),
             (w * 0.72, h - 26), (w * 0.88, h - 10), (w, h)]
    o.append(O(smooth(ridge)))
    cx = w * 0.5
    ty = h - 41.6
    o.append(O(f"M{f(cx - 11)},{f(ty + 1)} L{f(cx - 11)},{f(ty - 6)} L{f(cx + 11)},{f(ty - 6)} L{f(cx + 11)},{f(ty + 1)} Z"))
    o.append(L(f"M{f(cx - 12.6)},{f(ty - 6)} L{f(cx + 12.6)},{f(ty - 6)}"))
    o.append(O(f"M{f(cx - 6)},{f(ty - 6)} L{f(cx - 4.4)},{f(ty - 11)} L{f(cx + 4.4)},{f(ty - 11)} L{f(cx + 6)},{f(ty - 6)} Z"))
    o.append(O(f"M{f(cx - 3.4)},{f(ty - 11)} Q{f(cx)},{f(ty - 16.4)} {f(cx + 3.4)},{f(ty - 11)} Z"))
    o.append(L(f"M{f(cx)},{f(ty - 15)} L{f(cx)},{f(ty - 18)}"))
    for x in (cx - 7, cx, cx + 7):
        o.append(L(f"M{f(x - 1.6)},{f(ty + 1)} L{f(x - 1.6)},{f(ty - 2.6)} Q{f(x)},{f(ty - 4.4)} {f(x + 1.6)},{f(ty - 2.6)} L{f(x + 1.6)},{f(ty + 1)}"))
    steps = [(w * 0.66, h), (w * 0.6, h - 8), (w * 0.68, h - 16), (w * 0.58, h - 26), (w * 0.53, h - 36), (cx + 1, ty + 1)]
    o.append(L(smooth(steps), ' stroke-dasharray="2.4 2.6"'))
    return "".join(o)


def big_temple(sw):
    """Thanjavur Brihadeeswarar: two-storey walls with pilasters, a straight 13-tier pyramid, the great
    round cupola (kumbam) with a kalasam. Box 90 x 150."""
    o = []
    o.append(O("M6,150 L6,98 L84,98 L84,150 Z"))
    o.append(L("M3,150 L87,150"))
    o.append(L("M4.6,98 L85.4,98 M6,124 L84,124 M4.6,126 L85.4,126"))
    for y0, y1 in ((126, 148), (100, 122)):
        for x in (14, 26, 38, 52, 64, 76):
            o.append(L(f"M{f(x)},{f(y0 + 3)} L{f(x)},{f(y1 - 1)}"))
        for x in (20, 70):
            o.append(O(f"M{f(x - 3)},{f(y1 - 1)} L{f(x - 3)},{f(y0 + 7)} Q{f(x)},{f(y0 + 3)} {f(x + 3)},{f(y0 + 7)} L{f(x + 3)},{f(y1 - 1)} Z"))
    o.append(O("M40,148 L40,132 Q45,127 50,132 L50,148 Z"))
    # Pyramid.
    yb, yt = 98, 30
    lx = lambda y: 10 + (yb - y) * ((33 - 10) / (yb - yt))
    o.append(O(f"M{f(lx(yb))},{f(yb)} L{f(lx(yt))},{f(yt)} L{f(90 - lx(yt))},{f(yt)} L{f(90 - lx(yb))},{f(yb)} Z"))
    tiers = 13
    for i in range(1, tiers):
        y = yb - i * (yb - yt) / tiers
        o.append(L(f"M{f(lx(y) - 1)},{f(y)} L{f(90 - lx(y) + 1)},{f(y)}"))
    for i in range(0, tiers, 2):
        y0 = yb - (i + 1) * (yb - yt) / tiers
        o.append(L(f"M45,{f(y0 + 1.2)} L45,{f(y0 + (yb - yt) / tiers - 1.2)}"))
    # Griva, cupola, kalasam.
    o.append(O("M34,30 L34,25 L56,25 L56,30 Z"))
    o.append(O("M31,25 C31,13 38,9.4 45,9.4 C52,9.4 59,13 59,25 Z"))
    o.append(L("M37,25 C37,17 40.4,12.6 45,11.6 M53,25 C53,17 49.6,12.6 45,11.6"))
    o.append(O("M42,9.6 Q42,5.6 45,4.4 Q48,5.6 48,9.6 Z"))
    o.append(L("M45,4.4 L45,0.6"))
    return "".join(o)


def shore_temple(sw):
    """Mahabalipuram Shore Temple: two stepped pyramidal towers by the sea, waves in front. Box 110 x 84."""
    o = []
    def tower(cx, base_y, w, tiers, th):
        r = []
        r.append(O(f"M{f(cx - w / 2)},{f(base_y)} L{f(cx - w / 2)},{f(base_y - 14)} L{f(cx + w / 2)},{f(base_y - 14)} L{f(cx + w / 2)},{f(base_y)} Z"))
        for x in (cx - w / 4, cx + w / 4):
            r.append(L(f"M{f(x)},{f(base_y - 2)} L{f(x)},{f(base_y - 12)}"))
        y = base_y - 14
        ww = w
        for i in range(tiers):
            ww2 = ww * 0.78
            r.append(O(f"M{f(cx - ww / 2 - 1.6)},{f(y)} L{f(cx - ww2 / 2)},{f(y - th)} L{f(cx + ww2 / 2)},{f(y - th)} L{f(cx + ww / 2 + 1.6)},{f(y)} Z"))
            for k in (-1, 0, 1):
                xx = cx + k * ww2 * 0.28
                r.append(circ(xx, y - th * 0.45, 1.1, filled=False))
            y -= th
            ww = ww2
        r.append(O(f"M{f(cx - ww / 2)},{f(y)} Q{f(cx)},{f(y - ww * 0.9)} {f(cx + ww / 2)},{f(y)} Z"))
        r.append(L(f"M{f(cx)},{f(y - ww * 0.45)} L{f(cx)},{f(y - ww * 0.45 - 4)}"))
        return "".join(r)
    o.append(tower(70, 70, 26, 4, 7.4))
    o.append(tower(36, 70, 30, 5, 8))
    o.append(O("M14,70 L94,70 L98,74 L10,74 Z"))
    for x0, y in ((0, 79), (30, 83), (62, 79)):
        o.append(L(f"M{f(x0)},{f(y)} q6,-3.4 12,0 t12,0 t12,0 t12,0"))
    return "".join(o)


def kattumaram(sw):
    """Fishing kattumaram with a triangular sail and a fisherman, on waves. Box 80 x 60, faces right."""
    o = []
    o.append(L("M28,47 L29.4,8"))
    o.append(O("M30,9.6 Q48,20 58,44 L31,44 Z"))
    o.append(L("M31.4,22 Q40,26 46,34"))
    o.append(limb([(18.6, 37), (17.4, 44)], 3, sw))
    o.append(O("M14.4,37.6 L16,28 Q17,25.6 19,26 Q21,26.6 20.8,29 L20,38 Z"))
    o.append(limb([(19.6, 29.6), (24, 34), (28.4, 31.6)], 2.6, sw))
    o.append(circ(18, 22.6, 3.2))
    o.append(L("M14.8,21.4 Q18,18.4 21.4,21.4"))
    o.append(O("M4,44 L70,44 Q66,50.6 56,50.6 L10,50.6 Q6,50 4,44 Z"))
    o.append(L("M8,47.4 L66,47.4"))
    for x0, y in ((0, 55), (34, 58), (60, 54)):
        o.append(L(f"M{f(x0)},{f(y)} q4,-3 8,0 t8,0 t8,0"))
    return "".join(o)


def thanjavur_doll(sw):
    """Thanjavur thalaiyatti bommai (bobblehead doll): round-bottomed body, folded hands, crowned head.
    Box 34 x 46."""
    o = []
    o.append(O("M4,32 C4,22 9,17 17,17 C25,17 30,22 30,32 C30,40 24,45 17,45 C10,45 4,40 4,32 Z"))
    o.append(L("M5.6,36 Q17,40.4 28.4,36 M6,30 Q17,33 28,30"))
    o.append(O("M14.4,22 L17,17 L19.6,22 L18.4,27 L15.6,27 Z"))
    o.append(L("M10,20 Q12.6,24.4 15.6,24 M24,20 Q21.4,24.4 18.4,24"))
    o.append(rrect(15, 13.4, 4, 4.4, 1.2))
    o.append(circ(17, 10, 5))
    o.append(O("M12,8 L12.4,2.6 L14.6,4.8 L17,0.8 L19.4,4.8 L21.6,2.6 L22,8 Q17,6.4 12,8 Z"))
    o.append(circ(11.6, 12.6, 1.3))
    o.append(circ(22.4, 12.6, 1.3))
    o.append(dot(17, 9.6, 0.7))
    return "".join(o)


def veena(sw):
    """Saraswati veena (Thanjavur): big round resonator, long fretted neck, small gourd, yali head.
    Box 110 x 40."""
    o = []
    o.append(O("M83,14 C83,8 88,5 93,6 C99,7 101,12 99,17 C97,20.6 93,21 90,19.6 Z"))
    o.append(O("M24,12 L88,12 L88,20 L24,20 Z"))
    for x in range(32, 88, 6):
        o.append(L(f"M{f(x)},12 L{f(x)},20"))
    o.append(L("M24,14.4 L100,9 M24,17.6 L100,12"))
    o.append(O("M96,8 C102,4 108,6 109,12 C106,10 103,10 101,13 Z"))
    o.append(O("M2,22 C2,10 10,4 20,4 C30,4 37,11 37,22 C37,32 30,38 20,38 C10,38 2,32 2,22 Z"))
    o.append(L("M6,22 Q20,28 33,18"))
    o.append(O("M64,20 C64,26 67,30 71,30 C75,30 78,26 78,20 Z"))
    return "".join(o)


def filter_coffee(sw):
    """Filter coffee: steel tumbler standing in its davara, steam. Box 40 x 44."""
    o = []
    for x, d in ((14, 0), (21, 1)):
        o.append(L(f"M{f(x)},12 C{f(x - 3)},8.4 {f(x + 3)},5.6 {f(x)},2"))
    o.append(O("M2,34 L38,34 Q37,44 20,44 Q3,44 2,34 Z"))
    o.append(L("M0.6,34 L39.4,34"))
    o.append(O("M9.6,14 L30.4,14 L27.6,39 Q20,41 12.4,39 Z"))
    o.append(L("M8.4,14 L31.6,14 M10.6,19 L29.4,19"))
    return "".join(o)


def banana_leaf(sw):
    """Banana-leaf meal (virundhu): leaf with rice, idli, vada, sides. Box 90 x 34."""
    o = []
    o.append(O("M2,22 C10,6 40,2 88,8 C86,22 70,32 40,32 C20,32 6,29 2,22 Z"))
    o.append(L("M4,22 C30,17 60,15 86,9"))
    for x, y in ((14, 20), (24, 15.6), (32, 12.4)):
        o.append(L(f"M{f(x)},{f(y)} L{f(x + 3)},{f(y - 6)} M{f(x)},{f(y)} L{f(x + 4)},{f(y + 6)}"))
    o.append(O("M42,26 C42,20 48,18 53,19 C58,20 62,23 60,27 C56,30 44,30 42,26 Z"))
    o.append(circ(70, 20.6, 5))
    o.append(circ(70, 20.6, 1.6))
    o.append(O("M24,26 C24,23.4 26.4,22 29,22 C31.6,22 34,23.4 34,26 C34,28 31.6,29 29,29 C26.4,29 24,28 24,26 Z"))
    for x, y in ((40, 12), (50, 11), (60, 11.4)):
        o.append(circ(x, y, 2.4))
    return "".join(o)


def bullock_cart(sw):
    """Koodu vandi: covered bullock cart with a big spoked wheel, pulled by a Kangayam bull. Box 130 x 50."""
    o = []
    o.append(L("M44,34 L76,30"))
    o.append(O("M4,30 L48,30 L48,34 L4,34 Z"))
    o.append(O("M6,30 C6,14 12,8 26,8 C40,8 46,14 46,30 Z"))
    for x in (12, 19, 26, 33, 40):
        o.append(L(f"M{f(x)},{f(10 + abs(x - 26) * 0.5)} L{f(x)},30"))
    o.append(circ(24, 38, 11))
    o.append(circ(24, 38, 2.4))
    for a in range(0, 360, 45):
        r = math.radians(a)
        o.append(L(f"M{f(24 + math.cos(r) * 2.4)},{f(38 + math.sin(r) * 2.4)} L{f(24 + math.cos(r) * 10)},{f(38 + math.sin(r) * 10)}"))
    o.append(f'<g transform="translate(60,4)">{kangayam_bull(sw)}</g>')
    o.append(L("M0,50 L130,50"))
    return "".join(o)


def valluvar(sw):
    """Thiruvalluvar statue, Kanyakumari: robed poet with a top knot and beard, right forearm raised beside
    the face (three fingers up), palm-leaf book held at the waist, on a pillared pedestal on a sea rock.
    Box 54 x 132."""
    o = []
    o.append(O("M2,124 C4,116 10,112 16,112 L36,112 C42,112 47,117 48,124 Z"))
    for x0, y in ((-6, 128), (26, 130)):
        o.append(L(f"M{f(x0)},{f(y)} q5,-3 10,0 t10,0 t10,0"))
    o.append(O("M10,112 L10,104 L40,104 L40,112 Z"))
    o.append(O("M13,104 L13,86 L37,86 L37,104 Z"))
    for x in (18, 25, 32):
        o.append(L(f"M{f(x)},88 L{f(x)},102"))
    o.append(O("M10.6,86 L12,82 L38,82 L39.4,86 Z"))
    # Robe.
    o.append(O("M17,82 L18.6,44 Q19.6,36 25,35.6 Q30.4,36 31.4,44 L33,82 Z"))
    o.append(L("M19.4,41 Q25,49 31,40.6 M22.6,62 L23.6,81.4 M28,60 L28.6,81.4"))
    # Raised right forearm (viewer's right), three fingers.
    o.append(limb([(29.6, 40), (34.6, 50), (36, 37)], 3.6, sw))
    o.append(L("M35,35.4 L34.6,32.2 M36.4,35 L36.4,31.6 M37.8,35.4 L38.2,32.4"))
    # Left hand holding the palm-leaf book at the waist.
    o.append(limb([(20.4, 40), (17, 50), (21, 55)], 3.6, sw))
    o.append(O("M15.6,53 L27,53 L27,56.4 L15.6,56.4 Z"))
    o.append(L("M17,54.7 L25.6,54.7"))
    # Head, beard, top knot.
    o.append(rrect(23.2, 29.6, 3.6, 6, 1.2))
    o.append(circ(25, 25.4, 4.6))
    o.append(O("M20.8,26.6 C21,33 23,37.4 25,38.2 C27,37.4 29,33 29.2,26.6 C27.4,29.4 22.6,29.4 20.8,26.6 Z"))
    o.append(circ(25, 18.8, 2.6))
    return "".join(o)


def ayyanar_horse(sw):
    """Ayyanar terracotta horse: tall votive village horse, arched neck, decorated head and chest, saddle
    cloth, on a plinth. Box 76 x 84, faces right."""
    o = []
    o.append(O("M4,84 L4,76 L68,76 L68,84 Z"))
    o.append(L("M2,84 L70,84"))
    o.append(L("M14.6,38 C8.6,44 7.6,56 9.6,66"))
    for p in ([(20, 50), (19, 76)], [(26, 51), (26.4, 76)], [(45, 51), (45, 76)], [(50.4, 50), (51.4, 76)]):
        o.append(limb(p, 5, sw))
    o.append(O("M14,41 C13,33 18,29.6 25,29.4 L38,29 C42,22 47,13 55,8.4 L61.6,18 C58,26 56,33 54.4,40 "
               "C53,48 49,53.6 44,54 L20,54 C15.6,53.4 14,47 14,41 Z"))
    o.append(O("M54.6,9 C57,5 61,4 63.6,6.4 L72.2,16.6 C73.6,18.6 72.4,21.6 70,21.2 L62.4,19.4 "
               "C59.4,18.6 56.4,15 54.6,9 Z"))
    o.append(L("M56.6,6.6 L57,1.6 L59.8,4.6 M60.2,7.8 L66.6,18.6"))
    o.append(dot(62.2, 9.8, 0.9))
    o.append(L("M40.4,25.6 l-3.4,-1.4 M44.4,19.6 l-3.4,-1 M48.6,14 l-3.2,-0.8 M52.6,10 l-3,-0.4"))
    o.append(L("M47.4,24 Q53,29.4 58.6,24.6"))
    for x, y in ((49.4, 27), (53, 28.4), (56.6, 27.2)):
        o.append(circ(x, y, 1.3))
    o.append(O("M24,29.6 L40,29.4 L41.4,44.4 Q32,47.4 22.4,44.4 Z"))
    o.append(L("M23,40.4 Q32,43.4 41,40.4"))
    return "".join(o)


def elephant(sw):
    """Temple elephant: domed head with a namam on the forehead, big ear, hanging trunk, short tusk,
    back cloth and a bell. Box 80 x 60, faces right."""
    o = []
    for p in ([(22, 40), (22.4, 57)], [(52, 40), (52, 57)]):
        o.append(limb(p, 8, sw))
    o.append(L("M10.6,26 C7.4,30 7,36 8.4,42"))
    o.append(O("M10,32 C9,18 20,9 36,9 C44,9 50,10 55,12 C59,8 66,8 69.6,13 C72.4,17 72.6,22 71.4,27 "
               "C70.6,33 71.6,42 74.4,49 C75.6,52.4 73.4,55 70.8,53.8 L67.8,52.6 C66.4,44 66,38 65,34 "
               "C63.4,36 61,38 59,38 L59,44 C52,46.4 30,46.4 18,45.4 C12,44.4 10,38 10,32 Z"))
    o.append(O("M65,33 Q67.4,37.6 72,37.6 Q69,35 67.6,31.4 Z"))
    o.append(O("M50,14 C44,16 42,26 46,34 C49,38 55,38 58,34 C60,28 58,18 54,14 Z"))
    o.append(dot(62.6, 18.4, 1))
    o.append(L("M65.6,10.6 Q66.6,16 69.2,10.4 M67.4,11 L67.4,15"))
    o.append(O("M22,9.6 L44,9.6 L45,28 Q33,32 21,28 Z"))
    o.append(L("M21.6,24 Q33,28 44.6,24"))
    o.append(L("M57,37.6 L57,41"))
    o.append(O("M55,41 L59,41 L60,45 L54,45 Z"))
    for p in ([(18, 40), (18.4, 57)], [(46, 41), (46.4, 57)]):
        o.append(limb(p, 8.4, sw))
    return "".join(o)


def palmyra(sw, h=100):
    """Palmyra palm (panai, the state tree): straight trunk, a loose crown of big fan leaves on long stalks.
    Box 70 x h, trunk at x=35."""
    o = []
    cx, cy = 35, 26
    o.append(O(f"M32.2,{f(h)} L33.6,{f(cy + 2)} L36.4,{f(cy + 2)} L37.8,{f(h)} Z"))
    for y in range(int(cy + 10), int(h) - 2, 7):
        o.append(L(f"M33.4,{f(y)} L36.6,{f(y + 1.4)}"))
    def fan(a, R, stalk, spread=74):
        r = math.radians(a)
        fx, fy = cx + math.cos(r) * stalk, cy + math.sin(r) * stalk
        res = [L(f"M{f(cx)},{f(cy)} Q{f(cx + math.cos(r) * stalk * 0.5)},{f(cy + math.sin(r) * stalk * 0.5 - 2)} {f(fx)},{f(fy)}")]
        sp = math.radians(spread)
        n = 10
        pts = [(fx, fy)]
        for k in range(n + 1):
            aa = r - sp / 2 + sp * k / n
            rr = R * (0.84 if k % 2 else 1.0)
            pts.append((fx + math.cos(aa) * rr, fy + math.sin(aa) * rr))
        res.append(O(poly(pts, closed=True)))
        for k in range(2, n - 1, 2):
            aa = r - sp / 2 + sp * k / n
            res.append(L(poly([(fx, fy), (fx + math.cos(aa) * R * 0.76, fy + math.sin(aa) * R * 0.76)])))
        return "".join(res)
    for a, R, st in ((150, 11, 9), (30, 11, 9), (195, 14, 12), (345, 14, 12), (235, 14, 11), (305, 14, 11), (270, 13, 9)):
        o.append(fan(a, R, st))
    return "".join(o)


def plough_team(sw):
    """Farmer + plough + a yoked pair of Kangayam bulls on a ploughed field. Box 170 x 62, ground 58."""
    o = []
    gy = 58
    bx = 84
    o.append(f'<g transform="translate({f(bx + 14)},{f(gy - 46 - 2.6)})">{kangayam_bull(sw)}</g>')
    o.append(L(f"M{f(bx + 50)},{f(gy - 32)} L60.4,{f(gy - 16)}"))
    o.append(f'<g transform="translate({f(bx)},{f(gy - 46)})">{kangayam_bull(sw)}</g>')
    o.append(L(f"M{f(bx + 47.6)},{f(gy - 46 + 11.6)} L{f(bx + 62)},{f(gy - 46 + 8.4)}", f' stroke-width="{f(sw * 2.2)}"'))
    o.append(limb([(57, gy - 24), (61.4, gy - 2.6)], 2.6, sw))
    o.append(O(f"M59.4,{f(gy - 5)} L67.4,{f(gy + 0.4)} L60.6,{f(gy + 0.4)} Z"))
    o.append(limb([(57.6, gy - 22), (41.4, gy - 44.6)], 2.2, sw))
    o.append(f'<g transform="translate({f(41.4 - 28)},{f(gy - 44.6 - 27)})">{farmer(sw)}</g>')
    o.append(L(f"M0,{f(gy)} L170,{f(gy)}"))
    for y, x0, x1 in ((gy + 3.4, 4, 62), (gy + 6.8, 16, 54)):
        o.append(L(f"M{f(x0)},{f(y)} L{f(x1)},{f(y)}", ' stroke-dasharray="7 4"'))
    return "".join(o)

def kolam_border(sw, w=200, s=10, a=4.2):
    """Kolam border: a row of dots with two waves in opposite phase looping round each dot."""
    o = []
    n = int(w // s)
    x0 = (w - (n - 1) * s) / 2
    for ph in (1, -1):
        pts = []
        for i in range(n * 4 + 1):
            x = x0 - s / 2 + i * s / 4
            pts.append((x, ph * a * math.sin((x - x0 + s / 2) / s * math.pi)))
        o.append(L(smooth(pts)))
    o.append(L(f"M{f(x0 - s / 2)},0 C{f(x0 - s)},{f(-a * 1.4)} {f(x0 - s)},{f(a * 1.4)} {f(x0 - s / 2)},0"))
    xe = x0 + (n - 1) * s + s / 2
    o.append(L(f"M{f(xe)},0 C{f(xe + s / 2)},{f(-a * 1.4)} {f(xe + s / 2)},{f(a * 1.4)} {f(xe)},0"))
    for i in range(n):
        o.append(dot(x0 + i * s, 0, 0.95))
    return "".join(o)


def kolam_flower(sw, R=16, petals=8):
    """Flower kolam: a centre dot in a ring, eight petal loops each holding a dot, dots between the tips.
    Centred on (0,0)."""
    o = []
    for i in range(petals):
        a = 2 * math.pi * i / petals - math.pi / 2
        da = math.pi / petals
        tip = (math.cos(a) * R * 1.12, math.sin(a) * R * 1.12)
        l = (math.cos(a - da * 0.95) * R * 0.38, math.sin(a - da * 0.95) * R * 0.38)
        r = (math.cos(a + da * 0.95) * R * 0.38, math.sin(a + da * 0.95) * R * 0.38)
        cl = (math.cos(a - da * 0.75) * R * 1.18, math.sin(a - da * 0.75) * R * 1.18)
        cr = (math.cos(a + da * 0.75) * R * 1.18, math.sin(a + da * 0.75) * R * 1.18)
        o.append(L(f"M{pt(l)} C{pt(cl)} {pt(tip)} {pt(tip)} C{pt(tip)} {pt(cr)} {pt(r)}"))
        o.append(dot(math.cos(a) * R * 0.72, math.sin(a) * R * 0.72, 0.95))
        b = a + da
        o.append(dot(math.cos(b) * R * 1.02, math.sin(b) * R * 1.02, 0.95))
    o.append(circ(0, 0, R * 0.32, filled=False))
    o.append(dot(0, 0, 1.1))
    return "".join(o)
