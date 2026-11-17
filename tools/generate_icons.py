#!/usr/bin/env python3
"""Generate Wird launcher icons (pink theme) with PIL — no text, no emoji.

Legacy ic_launcher.png per density: pink gradient rounded square,
white open book, gold bookmark ribbon.
Adaptive foreground (ic_launcher_foreground.png per density): same book
drawn inside the safe zone on transparency; background is the solid
deep-rose color referenced by mipmap-anydpi-v26/ic_launcher.xml.
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res")
DEEP_ROSE = (173, 20, 87)
PINK = (236, 64, 122)
LIGHT_PINK = (248, 187, 208)
GOLD = (201, 162, 39)
WHITE = (255, 255, 255)

DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
SS = 4  # supersampling


def gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / max(1, size - 1)
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = c
    return img


def draw_book(d, cx, cy, w, h):
    """White open book centered at (cx, cy), width w, height h, plus gold ribbon."""
    left = cx - w / 2
    right = cx + w / 2
    top = cy - h / 2
    bottom = cy + h / 2
    # pages: left and right, spine dipping in the middle
    d.polygon([(left, top + h * 0.12), (cx, top), (cx, bottom),
               (left, bottom - h * 0.12)], fill=WHITE)
    d.polygon([(right, top + h * 0.12), (cx, top), (cx, bottom),
               (right, bottom - h * 0.12)], fill=(255, 241, 246))
    # spine
    d.line([(cx, top), (cx, bottom)], fill=LIGHT_PINK, width=max(3, int(w * 0.02)))
    # page lines (soft pink)
    for i in range(3):
        y = top + h * (0.30 + 0.18 * i)
        d.line([(left + w * 0.09, y + h * 0.03), (cx - w * 0.07, y)],
               fill=LIGHT_PINK, width=max(3, int(w * 0.016)))
        d.line([(cx + w * 0.07, y), (right - w * 0.09, y + h * 0.03)],
               fill=LIGHT_PINK, width=max(3, int(w * 0.016)))
    # gold bookmark ribbon hanging from the top of the right page
    rw = w * 0.10
    rx = cx + w * 0.26
    ry_top = top - h * 0.02
    ry_bot = bottom - h * 0.18
    d.polygon([(rx, ry_top), (rx + rw, ry_top), (rx + rw, ry_bot),
               (rx + rw / 2, ry_bot - h * 0.12), (rx, ry_bot)], fill=GOLD)


def legacy_icon(px):
    size = px * SS
    base = gradient(size, PINK, DEEP_ROSE).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    r = int(size * 0.22)
    md.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask)
    d = ImageDraw.Draw(out)
    draw_book(d, size / 2, size / 2, size * 0.62, size * 0.52)
    return out.resize((px, px), Image.LANCZOS)


def foreground_icon(px):
    size = px * SS
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    # adaptive safe zone: keep the book within the central ~62%
    draw_book(d, size / 2, size / 2, size * 0.46, size * 0.38)
    return out.resize((px, px), Image.LANCZOS)


def main():
    for name, scale in DENSITIES.items():
        folder = os.path.join(ROOT, f"mipmap-{name}")
        os.makedirs(folder, exist_ok=True)
        legacy_icon(round(48 * scale)).save(os.path.join(folder, "ic_launcher.png"))
        foreground_icon(round(108 * scale)).save(
            os.path.join(folder, "ic_launcher_foreground.png"))
        print("wrote", name)
    print("done")


if __name__ == "__main__":
    main()
