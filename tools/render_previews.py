#!/usr/bin/env python3
"""Drawn app previews (NOT device screenshots) for «وِرد» — pink theme.

Renders 3 phone previews at 1080x1920 with PIL:
  1) Home with the «واقف وين؟» standing-marker card
  2) Mushaf page with a pink-highlighted ayah + «موضع الوقوف» chip
  3) Repetition settings / player with pink controls

Arabic shaping: PIL/raqm native RTL when available; otherwise
arabic_reshaper + python-bidi fallback. Fonts come from the project
(IBM Plex Sans Arabic for UI, Amiri Quran for Quranic text).
Real ayah texts are read from assets/data/quran.json — nothing typed by hand.
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont, features

try:
    import arabic_reshaper
    from bidi.algorithm import get_display
    HAS_RESHAPER = True
except Exception:
    HAS_RESHAPER = False

HAS_RAQM = features.check("raqm")

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.join(HERE, "..")
OUT_DIR = os.path.expanduser("~/workspace/wird-previews")
os.makedirs(OUT_DIR, exist_ok=True)

W, H = 1080, 1920
DEEP = (173, 20, 87)
PINK = (236, 64, 122)
LIGHT = (248, 187, 208)
SOFT = (252, 228, 236)
BLUSH = (255, 240, 245)
BG = (255, 251, 252)
GOLD = (201, 162, 39)
GOLD_SOFT = (247, 236, 208)
DARK = (74, 43, 53)
MUTED = (138, 109, 118)
WHITE = (255, 255, 255)

F_UI = os.path.join(PROJ, "assets/fonts/IBMPlexSansArabic-Regular.ttf")
F_UIB = os.path.join(PROJ, "assets/fonts/IBMPlexSansArabic-Bold.ttf")
F_QURAN = os.path.join(PROJ, "assets/fonts/AmiriQuran.ttf")


def font(path, size):
    return ImageFont.truetype(path, size)


def ar(draw, xy, text, fnt, fill, anchor="ra", **kw):
    """Draw Arabic text right-anchored at xy (RTL)."""
    if HAS_RAQM:
        draw.text(xy, text, font=fnt, fill=fill, anchor=anchor,
                  direction="rtl", language="ar", **kw)
    elif HAS_RESHAPER:
        visual = get_display(arabic_reshaper.reshape(text))
        # visual-order string: draw it left-aligned ending at xy[0]
        w = draw.textlength(visual, font=fnt)
        draw.text((xy[0] - w, xy[1]), visual, font=fnt, fill=fill, **kw)
    else:
        draw.text(xy, text, font=fnt, fill=fill, anchor=anchor, **kw)


def ar_center(draw, cx, y, text, fnt, fill):
    if HAS_RAQM:
        draw.text((cx, y), text, font=fnt, fill=fill, anchor="ma",
                  direction="rtl", language="ar")
    else:
        ar(draw, (cx + draw.textlength(text, font=fnt) / 2, y), text, fnt, fill)


def text_w(draw, text, fnt):
    if HAS_RAQM:
        return draw.textlength(text, font=fnt, direction="rtl", language="ar")
    if HAS_RESHAPER:
        return draw.textlength(get_display(arabic_reshaper.reshape(text)), font=fnt)
    return draw.textlength(text, font=fnt)


def wrap_rtl(draw, text, fnt, max_w):
    """Word-wrap logical Arabic text; returns list of logical lines."""
    lines, cur = [], ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        if text_w(draw, trial, fnt) <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def vgrad(size, top, bottom):
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(size[0]):
            px[x, y] = c
    return img


def hgrad(size, left, right):
    img = Image.new("RGB", size)
    px = img.load()
    for x in range(size[0]):
        t = x / max(1, size[0] - 1)
        c = tuple(round(left[i] + (right[i] - left[i]) * t) for i in range(3))
        for y in range(size[1]):
            px[x, y] = c
    return img


def rrect(draw, box, radius, **kw):
    draw.rounded_rectangle(box, radius=radius, **kw)


def chrome(draw, title):
    """Status bar + pink app bar."""
    draw.rectangle([0, 0, W, 64], fill=DEEP)
    draw.text((36, 14), "9:41", font=font(F_UI, 30), fill=WHITE)
    for i, wd in enumerate([26, 20, 14]):
        draw.rounded_rectangle([W - 150 + i * 38, 44 - wd, W - 128 + i * 38, 44],
                               radius=3, fill=WHITE)
    draw.rectangle([0, 64, W, 214], fill=DEEP)
    ar_center(draw, W / 2, 96, title, font(F_UIB, 46), WHITE)
    # simple back chevron (points right in RTL = back)
    draw.line([(W - 84, 118), (W - 58, 140), (W - 84, 162)], fill=WHITE, width=6)


def bookmark(draw, x, y, s, color):
    draw.polygon([(x, y), (x + s, y), (x + s, y + s * 1.5),
                  (x + s / 2, y + s * 1.12), (x, y + s * 1.5)], fill=color)


def mini_book(draw, cx, cy, w, h, color):
    left, right = cx - w / 2, cx + w / 2
    top, bottom = cy - h / 2, cy + h / 2
    lp = [(left, top + h * .12), (cx, top), (cx, bottom), (left, bottom - h * .12)]
    rp = [(right, top + h * .12), (cx, top), (cx, bottom), (right, bottom - h * .12)]
    draw.polygon(lp, fill=WHITE)
    draw.polygon(rp, fill=WHITE)
    draw.line(lp + [lp[0]], fill=color, width=3)
    draw.line(rp + [rp[0]], fill=color, width=3)


# ---------------------------------------------------------------- home
def preview_home(quran):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    chrome(d, "وِرد – القرآن الكريم")
    ar_center(d, W / 2, 238, "بسم الله الرحمن الرحيم", font(F_QURAN, 50), DEEP)
    ar_center(d, W / 2, 362,
              "تلاوة الشيخ الزين محمد أحمد — حفظ ومراجعة بتكرار دقيق",
              font(F_UI, 30), MUTED)

    # --- standing marker gradient card
    card = hgrad((984, 420), DEEP, PINK).convert("RGB")
    mask = Image.new("L", card.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, card.size[0] - 1, card.size[1] - 1],
                                           radius=36, fill=255)
    img.paste(card, (48, 430), mask)
    d = ImageDraw.Draw(img)
    bookmark(d, 920, 472, 34, WHITE)
    ar(d, (880, 462), "واقف وين؟", font(F_UIB, 48), WHITE)
    ar(d, (984, 558), "سورة البقرة — الآية ٢٥٥", font(F_UIB, 46), WHITE)
    ar(d, (984, 628), "آخر تحديث: اليوم", font(F_UI, 32), LIGHT)
    labels = ["كمّل من هنا", "اسمع من هنا", "كرّر من هنا"]
    bw = 296
    for i, lab in enumerate(labels):
        x1 = 984 - i * (bw + 18) - bw
        rrect(d, [x1, 716, x1 + bw, 812], 24, fill=WHITE)
        ar_center(d, x1 + bw / 2, 740, lab, font(F_UIB, 31), DEEP)

    # --- daily goal card
    rrect(d, [48, 880, 1032, 1120], 32, fill=WHITE, outline=LIGHT, width=3)
    d.ellipse([782, 915, 972, 1105], outline=SOFT, width=18)
    d.arc([782, 915, 972, 1105], start=-90, end=162, fill=PINK, width=18)
    ar_center(d, 877, 982, "٧٠", font(F_UIB, 42), DARK)
    ar(d, (722, 945), "هدف اليوم", font(F_UIB, 40), DARK)
    ar(d, (722, 1015), "٧ من ١٠ آيات", font(F_UI, 34), MUTED)

    # --- shortcut grid
    items = ["بدء الحفظ", "بدء المراجعة", "تصفّح المصحف",
             "الاستماع", "الإنجاز والإحصائيات", "المفضلة"]
    cw, chh, gap, y0 = 480, 185, 22, 1170
    for i, lab in enumerate(items):
        col, row = i % 2, i // 2
        # RTL: first item at right
        x1 = 1032 - col * (cw + gap) - cw
        y1 = y0 + row * (chh + gap)
        rrect(d, [x1, y1, x1 + cw, y1 + chh], 28, fill=WHITE, outline=LIGHT, width=3)
        d.ellipse([x1 + cw / 2 - 44, y1 + 26, x1 + cw / 2 + 44, y1 + 114], fill=SOFT)
        mini_book(d, x1 + cw / 2, y1 + 70, 52, 42, DEEP)
        ar_center(d, x1 + cw / 2, y1 + 126, lab, font(F_UIB, 31), DARK)

    # --- player bar
    d.rectangle([0, 1792, W, H], fill=DEEP)
    d.ellipse([884, 1812, 972, 1900], outline=WHITE, width=5)
    d.polygon([(917, 1830), (917, 1882), (952, 1856)], fill=WHITE)
    ar(d, (840, 1838), "سورة البقرة — الآية ٢٥٥", font(F_UI, 32), WHITE)
    img.save(os.path.join(OUT_DIR, "preview-home.png"))
    print("preview-home.png")


# ---------------------------------------------------------------- mushaf
def preview_mushaf(quran):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    chrome(d, "سورة الفاتحة")
    surah = quran["surahs"][0]
    ayahs = surah["ayahs"]

    # bismillah band
    rrect(d, [0, 214, W, 376], 0, fill=GOLD_SOFT)
    ar_center(d, W / 2, 256, ayahs[0]["text"], font(F_QURAN, 46), DEEP)

    qf = font(F_QURAN, 47)
    y = 420
    standing_ayah = 2
    digits = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")
    for a in ayahs[:6]:
        n = a["numberInSurah"]
        text = a["text"] + "  ﴿" + str(n).translate(digits) + "﴾"
        lines = wrap_rtl(d, text, qf, 920)
        block_h = len(lines) * 100 + 54 + (78 if n == standing_ayah else 0)
        if n == standing_ayah:
            rrect(d, [36, y - 14, 1044, y + block_h], 24,
                  fill=SOFT, outline=DEEP, width=4)
        ly = y + 6
        for ln in lines:
            ar(d, (984, ly), ln, qf, (30, 30, 30))
            ly += 100
        # meta line / standing chip
        if n == standing_ayah:
            chip_w, chip_h = 300, 62
            cx1, cy1 = 1044 - 36 - chip_w, y + block_h - chip_h - 10
            rrect(d, [cx1, cy1, cx1 + chip_w, cy1 + chip_h], 31, fill=DEEP)
            bookmark(d, cx1 + chip_w - 52, cy1 + 14, 22, WHITE)
            ar(d, (cx1 + chip_w - 66, cy1 + 10), "موضع الوقوف",
               font(F_UIB, 30), WHITE)
            y += block_h + 62
        else:
            ar(d, (984, ly + 4), "الجزء ١ • صفحة ١", font(F_UI, 24), MUTED)
            y += block_h + 26
        if y > 1600:
            break

    # font-size bar
    d.rectangle([0, 1700, W, H], fill=WHITE)
    d.line([0, 1700, W, 1700], fill=LIGHT, width=3)
    ar(d, (1032, 1745), "حجم الخط ٢٦", font(F_UI, 32), DARK)
    d.line([120, 1845, 900, 1845], fill=LIGHT, width=8)
    d.line([480, 1845, 900, 1845], fill=PINK, width=8)
    d.ellipse([456, 1821, 504, 1869], fill=DEEP)
    img.save(os.path.join(OUT_DIR, "preview-mushaf.png"))
    print("preview-mushaf.png")


# ---------------------------------------------------------------- player
def preview_player(quran):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    chrome(d, "المشغّل — إعدادات التكرار")
    fatiha2 = quran["surahs"][1]["ayahs"][2]["text"]  # البقرة ٣

    ar_center(d, W / 2, 262, "سورة البقرة", font(F_UIB, 52), DARK)
    lines = wrap_rtl(d, fatiha2, font(F_QURAN, 46), 900)
    y = 350
    for ln in lines[:3]:
        ar_center(d, W / 2, y, ln, font(F_QURAN, 46), (30, 30, 30))
        y += 92
    y += 28

    # repetition progress chip
    rrect(d, [240, y + 26, 840, y + 116], 45, fill=GOLD_SOFT)
    ar_center(d, W / 2, y + 44, "الآية ٣ — التكرار ٢ من ٣", font(F_UIB, 36), DARK)
    y += 170

    # big play button
    cy = y + 130
    d.ellipse([W / 2 - 95, cy - 95, W / 2 + 95, cy + 95], fill=DEEP)
    d.polygon([(W / 2 - 30, cy - 48), (W / 2 - 30, cy + 48),
               (W / 2 + 52, cy)], fill=WHITE)
    d.ellipse([W / 2 - 300, cy - 55, W / 2 - 190, cy + 55], outline=MUTED, width=6)
    d.ellipse([W / 2 + 190, cy - 55, W / 2 + 300, cy + 55], outline=MUTED, width=6)
    # skip glyphs inside the side circles
    d.polygon([(W / 2 - 262, cy - 20), (W / 2 - 262, cy + 20),
               (W / 2 - 228, cy)], fill=MUTED)
    d.rectangle([W / 2 - 226, cy - 20, W / 2 - 218, cy + 20], fill=MUTED)
    d.polygon([(W / 2 + 262, cy - 20), (W / 2 + 262, cy + 20),
               (W / 2 + 228, cy)], fill=MUTED)
    d.rectangle([W / 2 + 218, cy - 20, W / 2 + 226, cy + 20], fill=MUTED)
    ar_center(d, W / 2, cy + 130, "أنا واقف هنا", font(F_UIB, 32), DEEP)
    bookmark(d, W / 2 + 105, cy + 138, 20, DEEP)
    y = cy + 220

    # mode chips
    ar(d, (1032, y), "نمط التكرار", font(F_UIB, 38), DARK)
    y += 70
    modes = ["كل آية وحدها", "مجموعات آيات", "النطاق كاملًا"]
    x = 1032
    for i, m in enumerate(modes):
        wdt = text_w(d, m, font(F_UI, 32)) + 56
        x -= wdt
        if i == 0:
            rrect(d, [x, y, x + wdt, y + 76], 38, fill=DEEP)
            ar_center(d, x + wdt / 2, y + 16, m, font(F_UIB, 32), WHITE)
        else:
            rrect(d, [x, y, x + wdt, y + 76], 38, fill=WHITE, outline=LIGHT, width=3)
            ar_center(d, x + wdt / 2, y + 16, m, font(F_UI, 32), DARK)
        x -= 16
    y += 120

    # count chips
    ar(d, (1032, y), "عدد مرات التكرار", font(F_UIB, 38), DARK)
    y += 70
    counts = ["١", "٢", "٣", "٥", "١٠", "مستمر"]
    x = 1032
    for i, c in enumerate(counts):
        wdt = 108 if len(c) < 3 else 170
        x -= wdt
        sel = c == "٣"
        rrect(d, [x, y, x + wdt, y + 84], 42,
              fill=DEEP if sel else WHITE,
              outline=None if sel else LIGHT, width=3)
        ar_center(d, x + wdt / 2, y + 18, c, font(F_UIB, 34),
                  WHITE if sel else DARK)
        x -= 14
    y += 150

    # gap slider
    ar(d, (1032, y), "الفاصل بين التكرارات: ١ ثانية", font(F_UI, 34), DARK)
    y += 76
    d.line([90, y, 990, y], fill=LIGHT, width=9)
    d.line([700, y, 990, y], fill=PINK, width=9)
    d.ellipse([676, y - 24, 724, y + 24], fill=DEEP)
    y += 90

    # start button
    rrect(d, [48, y, 1032, y + 116], 28, fill=DEEP)
    ar_center(d, W / 2, y + 32, "بدء التكرار", font(F_UIB, 40), WHITE)
    img.save(os.path.join(OUT_DIR, "preview-player.png"))
    print("preview-player.png")


def main():
    with open(os.path.join(PROJ, "assets/data/quran.json"), encoding="utf-8") as f:
        quran = json.load(f)
    print("raqm:", HAS_RAQM, "| reshaper fallback:", HAS_RESHAPER)
    preview_home(quran)
    preview_mushaf(quran)
    preview_player(quran)


if __name__ == "__main__":
    main()
