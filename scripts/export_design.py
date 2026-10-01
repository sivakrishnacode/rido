#!/usr/bin/env python3
"""Refreshes docs/design/ from the apps: renders every screen (Design gallery frames plus the screens added after
the design) with each app's test/tool/design_export_test.dart, then rebuilds index.md and index.csv.

    python3 scripts/export_design.py            # render both apps and rebuild docs/design
    python3 scripts/export_design.py --no-render  # rebuild from an earlier render in build/design_export

Needs Flutter (scripts/flutter.sh finds it) and Pillow.
"""
import csv, os, re, shutil, subprocess, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'docs', 'design')
RENDER = os.path.join(ROOT, 'build', 'design_export')
APPS = ['passenger', 'driver']

# Screens behind the paid-plan switch (driverPlansEnabled), off while the app is free.
PLAN_FRAMES = {'D-11', 'D-12a', 'D-12b', 'D-24', 'D-24b', 'D-24c', 'D-25a', 'D-25b', 'S-14'}
# Frames in the original design export (docs/design before 1 Oct 2026).
ORIGINAL = set('''P-01 P-02a P-02b P-02c P-03 P-04 P-05 P-06 P-07 P-07b P-08 P-09 P-10 P-11 P-12 P-13 P-14 P-15 P-16 P-17
P-18 P-19 P-20 P-21 P-22 P-23 P-23b P-24 P-24b P-25 P-25b PP-01 PP-02 PP-03 PP-04 PP-05 PP-06 PP-07 PP-08 PP-09 PP-10
D-01 D-02 D-03a D-03b D-04 D-05 D-06 D-07 D-08a D-08b D-09 D-10 D-11 D-12a D-12b D-13 D-14 D-14b D-15 D-16 D-17
D-17-error D-18 D-18b D-19 D-20 D-21 D-22a D-22b D-23 D-23b D-24 D-24b D-24c D-25a D-25b D-26 S-01 S-02 S-03 S-04
S-05 S-06 S-07a S-07b S-08 S-09 S-10 S-11 S-12 S-13 S-14 S-15 S-16'''.split())


def frames(app):
    """(id, name) in gallery order, then the screens added after the design (an extra with a gallery ID replaces it)."""
    reg = open(os.path.join(ROOT, 'apps', app, 'lib/features/design_gallery/gallery_registry.dart')).read()
    gallery = re.findall(r"_e\('([^']+)', '([^']+)'", reg)
    tool = open(os.path.join(ROOT, 'apps', app, 'test/tool/design_export_test.dart')).read()
    extras = re.findall(r"\(id: '([^']+)', name: (?:'([^']*)'|\"([^\"]*)\")", tool)
    extras = [(i, a or b) for i, a, b in extras]
    names = dict(gallery)
    names.update(extras)
    order = [i for i, _ in gallery if i != 'DS'] + [i for i, _ in extras if i not in dict(gallery)]
    return [(i, names[i]) for i in order]


def folder(frame_id):
    if frame_id.startswith('PP-'):
        return 'parcel'
    if frame_id.startswith('P-'):
        return 'passenger'
    if frame_id.startswith('D-'):
        return 'driver'
    return 'states'


def status(frame_id, app):
    if frame_id in PLAN_FRAMES:
        return 'Off while the app is free (paid plans switched off)'
    if frame_id not in ORIGINAL:
        return 'Added after the design'
    if app == 'driver' and frame_id == 'D-05':
        return 'As in the flow (plans off: no price)'
    return 'In the app'


def main():
    if '--no-render' not in sys.argv:
        for app in APPS:
            out = os.path.join(RENDER, app)
            shutil.rmtree(out, ignore_errors=True)
            os.makedirs(out)
            subprocess.run(['sh', '../../scripts/flutter.sh', 'test', 'test/tool/design_export_test.dart',
                            f'--dart-define=OUT_DIR={out}'], cwd=os.path.join(ROOT, 'apps', app), check=True)
    for sub in ['system', 'passenger', 'parcel', 'driver', 'states']:
        shutil.rmtree(os.path.join(OUT, sub), ignore_errors=True)
        os.makedirs(os.path.join(OUT, sub))

    def copy(src, dest):
        Image.open(src).save(os.path.join(OUT, dest), optimize=True)

    rows = []
    boards = sorted(f for f in os.listdir(os.path.join(RENDER, 'passenger')) if f.startswith('DS-board-'))
    for i, f in enumerate(boards, 1):
        copy(os.path.join(RENDER, 'passenger', f), f'system/{f}')
        rows.append(('DS', f'Design system board · page {i} of {len(boards)}', 'both', f'system/{f}', 'In the app'))
    for app in APPS:
        for frame_id, name in frames(app):
            src = os.path.join(RENDER, app, f'{frame_id}.png')
            if not os.path.exists(src):
                sys.exit(f'missing render: {src}')
            dest = f'{folder(frame_id)}/{frame_id}.png'
            copy(src, dest)
            rows.append((frame_id, name, app, dest, status(frame_id, app)))

    with open(os.path.join(OUT, 'index.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        w.writerow(['frame_id', 'screen_name', 'app', 'file', 'status'])
        w.writerows(rows)

    def table(pred):
        lines = ['| Frame ID | Screen | Status | File |', '|---|---|---|---|']
        for frame_id, name, app, dest, st in rows:
            if pred(frame_id, app):
                lines.append(f'| {frame_id} | {name} | {st} | [{dest}]({dest}) |')
        return '\n'.join(lines)

    md = f'''# Tamil Taxi · screens

Screenshots of the apps as they are today, one per screen: every frame in each app's Design gallery
(Account › Design gallery) plus the screens added after the original design. Phone frames are 390 × 844 at 2x
(780 × 1688), rendered from the real widgets with seed data (mock mode).

**Refresh:** `python3 scripts/export_design.py` renders both apps (each app's `test/tool/design_export_test.dart`)
and rebuilds this folder and `index.csv`. Don't edit the PNGs by hand.

Notes:
- Maps show no tiles here (tests never load the network); on a phone they show CARTO or Google tiles.
- Areas on maps are H3 hexes, never circles: demand (res 7, nested res 8), the service-area outline and the
  search area; the search pulse grows as hexes too. Live maps draw the API's real H3 outlines.
- Tamil text and a few symbols (e.g. "→" in Poppins headings) show as boxes in these renders only: the test
  engine has no system fallback font. Phones render them.
- Paid-plan screens are still in the code but switched off (`driverPlansEnabled`), so riders and drivers don't
  see them while the app is free.
- Icons: Material Symbols Rounded (`material_symbols_icons`).

## Design system

{table(lambda i, a: i == 'DS')}

## Passenger app

{table(lambda i, a: a == 'passenger' and i.startswith('P-'))}

## Send parcel (passenger app)

{table(lambda i, a: a == 'passenger' and i.startswith('PP-'))}

## Passenger states

{table(lambda i, a: a == 'passenger' and i.startswith('S-'))}

## Driver app

{table(lambda i, a: a == 'driver' and i.startswith('D-'))}

## Driver states

{table(lambda i, a: a == 'driver' and i.startswith('S-'))}
'''
    open(os.path.join(OUT, 'index.md'), 'w').write(md)
    print(f'{len(rows)} screens written to {OUT}')


if __name__ == '__main__':
    main()
