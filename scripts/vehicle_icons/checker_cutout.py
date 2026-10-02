"""Cuts a render out of a painted checkerboard "transparent" background (an RGB file, no alpha). Pure PIL.

Image generators often paint the transparency checkerboard into the picture. It is a mix of two greys (dark
~140-155, light ~195-211) in ~11 px squares. A pixel is background when the window around it holds enough of BOTH
greys (a uniform grey panel holds only one) and it connects to the image border; the band next to the vehicle, where
the window also sees the vehicle, is grown back pixel by pixel while both greys are still close by.

Per render: [holes] are background the vehicle encloses (inside a roll bar), [windows] are panes the render paints as
see-through: the checker in them becomes cabin grey and the pane is tinted like the other renders' glass.
"""
from PIL import Image, ImageChops, ImageDraw, ImageFilter

GLASS = (30, 38, 50)
CABIN = (128, 134, 142)


def _thr(im, lo, hi=255):
    return im.point(lambda v: 255 if lo <= v <= hi else 0)


def _frac(mask, radius):
    """Share of [mask] pixels in a (2r+1)² window, 0-255."""
    return mask.filter(ImageFilter.BoxBlur(radius))


def _polygon(size, points):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return m


def cutout(path, windows=(), holes=()):
    """The render at [path] as RGBA with the checkerboard removed, trimmed to the vehicle."""
    rgb = Image.open(path).convert('RGB')
    r, g, b = rgb.split()
    L = rgb.convert('L')
    sat = ImageChops.subtract(ImageChops.lighter(ImageChops.lighter(r, g), b), ImageChops.darker(ImageChops.darker(r, g), b))
    grey = _thr(sat, 0, 24)
    dark = ImageChops.multiply(_thr(L, 126, 174), grey)
    light = ImageChops.multiply(_thr(L, 180, 226), grey)
    pix = ImageChops.lighter(dark, light)

    def mixed(d, l, radius, each, total=0.0):
        fd, fl = _frac(d, radius), _frac(l, radius)
        both = ImageChops.multiply(_thr(fd, round(each * 255)), _thr(fl, round(each * 255)))
        return ImageChops.multiply(both, _thr(ImageChops.add(fd, fl), round(total * 255)))

    core = mixed(dark, light, 7, 0.20, 0.70)
    # The window test is cut short at the image edge: there any checker grey counts (the border is background).
    w, h = rgb.size
    edge = Image.new('L', rgb.size, 255)
    edge.paste(0, (12, 12, w - 12, h - 12))
    core = ImageChops.lighter(core, ImageChops.multiply(edge, pix))
    near = ImageChops.multiply(mixed(dark, light, 5, 0.10), pix)  # both greys within ~11 px: still checker

    pad = Image.new('L', (w + 2, h + 2), 255)
    pad.paste(core, (1, 1))
    ImageDraw.floodfill(pad, (0, 0), 128, thresh=0)
    bg = pad.crop((1, 1, w + 1, h + 1)).point(lambda v: 255 if v == 128 else 0)
    for poly in holes:
        bg = ImageChops.lighter(bg, ImageChops.multiply(_polygon(rgb.size, poly), near))
    for _ in range(24):
        grown = ImageChops.lighter(bg, ImageChops.multiply(bg.filter(ImageFilter.MaxFilter(3)), near))
        if ImageChops.difference(grown, bg).getbbox() is None:
            break
        bg = grown

    out = rgb.copy()
    # Seen through glass the checker is lighter (~165-210): look for that mix too.
    gdark = ImageChops.multiply(_thr(L, 158, 189), grey)
    glight = ImageChops.multiply(_thr(L, 191, 224), grey)
    gpix = ImageChops.multiply(mixed(gdark, glight, 5, 0.15), ImageChops.lighter(gdark, glight))
    for poly in windows:
        pane = _polygon(rgb.size, poly)
        seen = ImageChops.multiply(pane, ImageChops.lighter(near, gpix).filter(ImageFilter.MaxFilter(3)))
        out.paste(Image.new('RGB', rgb.size, CABIN), mask=seen.filter(ImageFilter.GaussianBlur(1.2)))
        out.paste(Image.new('RGB', rgb.size, GLASS), mask=pane.point(lambda v: v * 80 // 100).filter(ImageFilter.GaussianBlur(1)))

    alpha = ImageChops.invert(bg).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.9))
    out = out.convert('RGBA')
    out.putalpha(alpha)
    return out.crop(alpha.point(lambda a: 255 if a > 16 else 0).getbbox())
