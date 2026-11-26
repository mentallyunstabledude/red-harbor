#!/usr/bin/env python3
"""Regenerate assets/sprites/menu_orbit_sheet.png - the ember orbit that
circles the title on the main menu, the way the old GIF loop did.

Eight 128x128 frames laid out in one 1024x128 strip. Two counter-rotating
rings of embers, each ember dragging a fading trail of ghosts behind it;
every ring turns through a whole number of revolutions per loop so the
flipbook cycles seamlessly. Halos are checker-dithered to sit right on the
tube's 5-bit dither. Run from the repo root:

    python3 assets_src/gen_orbit_sheet.py
"""
import math
import os

from PIL import Image

SIZE = 128
FRAMES = 8
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites",
                   "menu_orbit_sheet.png")

CX = CY = SIZE / 2.0

# (count, radius, direction, speed turns/loop, wobble amplitude, wobble turns)
RINGS = [
    (12, 44.0, +1.0, 1.0, 3.0, 2.0),
    (8, 27.0, -1.0, 1.0, 2.0, 3.0),
]

CORE = (255, 218, 148)
MID = (242, 124, 42)
OUTER = (152, 52, 20)
TRAIL = (196, 84, 30)


def blend(px, x, y, col, a):
    """src-over one pixel, clipped to the frame"""
    if not (0 <= x < SIZE and 0 <= y < SIZE) or a <= 0:
        return
    r, g, b, oa = px[x, y]
    na = a + oa * (1.0 - a)
    if na <= 0:
        return
    px[x, y] = (
        int((col[0] * a + r * oa * (1.0 - a)) / na),
        int((col[1] * a + g * oa * (1.0 - a)) / na),
        int((col[2] * a + b * oa * (1.0 - a)) / na),
        int(na * 255),
    )


def ember(px, x, y, r_halo, strength=1.0):
    """a bright core with a checker-dithered cooling halo"""
    for dy in range(-r_halo, r_halo + 1):
        for dx in range(-r_halo, r_halo + 1):
            d = math.hypot(dx, dy)
            if d > r_halo:
                continue
            t = 1.0 - d / r_halo
            if t < 0.5 and (x + dx + y + dy) % 2:      # the dither
                continue
            col = MID if t >= 0.45 else OUTER
            blend(px, x + dx, y + dy, col, min(1.0, t * 1.3) * 0.55 * strength)
    blend(px, x, y, CORE, 0.95 * strength)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        blend(px, x + dx, y + dy, CORE, 0.55 * strength)


def frame(t):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for count, radius, direction, turns, wob, wob_turns in RINGS:
        step = 2.0 * math.pi / count
        for i in range(count):
            base = i * step + direction * turns * 2.0 * math.pi * t
            r = radius + math.sin(wob_turns * 2.0 * math.pi * t + i * 2.3) * wob
            # the trail: ghosts a little way back along the same arc
            for k in range(10, 0, -1):
                a = base - direction * k * 0.028
                x = CX + math.cos(a) * r
                y = CY + math.sin(a) * r * 0.86      # a touch of ellipse
                blend(px, int(x), int(y), TRAIL,
                      0.34 * (1.0 - k / 11.0) * 0.7)
            x = CX + math.cos(base) * r
            y = CY + math.sin(base) * r * 0.86
            ember(px, int(round(x)), int(round(y)),
                  4 if radius > 30 else 3,
                  1.0 if radius > 30 else 0.8)
    return img


def main():
    sheet = Image.new("RGBA", (SIZE * FRAMES, SIZE), (0, 0, 0, 0))
    for f in range(FRAMES):
        sheet.paste(frame(f / FRAMES), (f * SIZE, 0))
    sheet.save(OUT)
    print("wrote %s (%dx%d, %d frames)" % (OUT, sheet.width, sheet.height, FRAMES))


if __name__ == "__main__":
    main()
