#!/usr/bin/env python3
"""Generate all 2D art for IGI 3 2D from local data (no downloads).

    python tools/make_visuals.py

Outputs actor sprites, the menu background and the README key art.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SPR = ROOT / "assets" / "sprites"
DOC = ROOT / "docs" / "images"
SPR.mkdir(parents=True, exist_ok=True)
DOC.mkdir(parents=True, exist_ok=True)

FONT = ROOT / "assets" / "fonts" / "NotoSans-Bold.ttf"
MAP = ROOT / "assets" / "maps" / "nikunja_osm.png"
GOLD = (214, 176, 98)
TEAL = (105, 198, 184)
CREAM = (240, 235, 220)
INK = (10, 18, 22)

PALETTE = {
    "owner": (36, 86, 88, GOLD),
    "customer": (92, 88, 82, (190, 185, 170)),
    "inspector": (38, 58, 92, (150, 180, 225)),
    "vendor": (110, 62, 30, (240, 160, 90)),
    "staff": (44, 72, 48, (150, 205, 140)),
    "quest_giver": (92, 60, 110, (225, 190, 240)),
    "vip": (120, 84, 40, (255, 220, 140)),
}


def sprite(name: str, spec) -> Image.Image:
    """Front-facing humanoid billboard with a little 2.5D shading."""
    body, accent = spec[:3], spec[3]
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    dark = tuple(int(c * 0.55) for c in body)
    light = tuple(min(255, int(c * 1.25)) for c in body)
    # legs
    d.rounded_rectangle((22, 42, 29, 60), radius=3, fill=dark + (255,))
    d.rounded_rectangle((35, 42, 42, 60), radius=3, fill=dark + (255,))
    # torso with side shading
    d.rounded_rectangle((19, 20, 45, 45), radius=7, fill=body + (255,),
                        outline=accent + (255,), width=1)
    d.rectangle((19, 20, 24, 45), fill=light + (255,))
    # arms
    d.rounded_rectangle((13, 22, 20, 42), radius=3, fill=dark + (255,))
    d.rounded_rectangle((44, 22, 51, 42), radius=3, fill=dark + (255,))
    # head, hair and face highlight
    d.ellipse((23, 5, 41, 23), fill=(205, 172, 138, 255))
    d.ellipse((23, 5, 41, 14), fill=(28, 34, 36, 255))
    d.ellipse((26, 12, 38, 22), fill=(218, 186, 150, 255))
    d.ellipse((28, 14, 30, 16), fill=(20, 22, 24, 255))
    d.ellipse((34, 14, 36, 16), fill=(20, 22, 24, 255))
    # weapon / accent
    d.line((48, 18, 48, 46), fill=accent + (255,), width=4)
    d.line((48, 18, 54, 18), fill=(235, 230, 210, 255), width=3)
    return im


def shadow_sprite() -> Image.Image:
    im = Image.new("RGBA", (64, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((4, 2, 60, 22), fill=(0, 0, 0, 120))
    return im


def ring_sprite(accent) -> Image.Image:
    im = Image.new("RGBA", (40, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((2, 2, 38, 16), outline=tuple(accent) + (210,), width=3)
    return im


def font(size):
    return ImageFont.truetype(str(FONT), size)


def dark_map(size, coverage=1.0):
    src = Image.open(MAP).convert("RGB")
    w, h = size
    scale = max(w / src.width, h / src.height) * coverage
    src = src.resize((int(src.width * scale), int(src.height * scale)), Image.LANCZOS)
    left = (src.width - w) // 2
    top = (src.height - h) // 2
    src = src.crop((left, top, left + w, top + h))
    src = ImageEnhance.Color(src).enhance(0.25)
    src = ImageEnhance.Brightness(src).enhance(0.42)
    return src


def menu_bg():
    w, h = 1280, 720
    im = dark_map((w, h), 1.25).convert("RGBA")
    over = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    d.rectangle((0, 0, w, h), fill=(5, 16, 20, 90))
    for x in range(0, w, 64):
        d.line((x, 0, x - 360, h), fill=(90, 190, 175, 22), width=2)
    d.rectangle((0, h - 8, w, h), fill=GOLD + (255,))
    im = Image.alpha_composite(im, over)
    im.convert("RGB").save(SPR / "menu_bg.png", optimize=True)


def sheet():
    cols = 4
    cw, ch = 120, 130
    rows = (len(PALETTE) + cols - 1) // cols
    im = Image.new("RGB", (cols * cw, rows * ch), INK)
    d = ImageDraw.Draw(im)
    for i, (name, spec) in enumerate(PALETTE.items()):
        x = (i % cols) * cw
        y = (i // cols) * ch
        sp = sprite(name, spec)
        im.paste(sp, (x + cw // 2 - 32, y + 4), sp)
        d.text((x + cw // 2, y + 72), name, font=font(14), fill=CREAM, anchor="mm")
    im.save(DOC / "sprites.png", optimize=True)


def banner():
    w, h = 1600, 620
    im = dark_map((w, h), 1.2).convert("RGBA")
    over = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    d.rectangle((0, 0, w, h), fill=(4, 14, 18, 120))
    d.rectangle((56, 50, 66, h - 50), fill=GOLD + (255,))
    d.text((96, 80), "NIKUNJA BAZAAR", font=font(124), fill=CREAM + (255,))
    d.text((102, 244), "RPG - REAL STREETS OF DHAKA", font=font(46), fill=GOLD + (255,))
    d.line((102, 320, 760, 320), fill=GOLD + (200,), width=3)
    d.text((104, 348), "15 BUSINESS NIGHTS  /  REAL OSM MARKET  /  GODOT 4.3",
           font=font(28), fill=TEAL + (255,))
    chips = ["REAL NIKUNJA OSM", "46 STALLS", "RPG SKILLS + QUESTS", "15 NIGHTS"]
    x = 104
    for c in chips:
        tw = d.textbbox((0, 0), c, font=font(20))[2]
        d.rounded_rectangle((x, 450, x + tw + 36, 506), radius=8,
                            fill=(10, 26, 30, 220), outline=GOLD + (190,), width=2)
        d.text((x + 18, 478), c, font=font(20), fill=TEAL + (255,), anchor="lm")
        x += tw + 54
    d.rectangle((0, h - 8, w, h), fill=GOLD + (255,))
    Image.alpha_composite(im, over).convert("RGB").save(DOC / "banner.png", optimize=True)


def map_overview():
    w, h = 1200, 760
    im = dark_map((w, h), 1.0).convert("RGBA")
    over = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    d.rectangle((0, 0, w, h), fill=(4, 12, 16, 45))
    d.rounded_rectangle((36, 34, 580, 158), radius=12, fill=(5, 13, 18, 230),
                        outline=GOLD + (220,), width=3)
    d.text((66, 76), "NIKUNJA, DHAKA", font=font(48), fill=CREAM + (255,))
    d.text((68, 130), "REAL OPENSTREETMAP FOOTPRINTS - DHAKA", font=font(20), fill=TEAL + (255,))
    d.rectangle((0, h - 10, w, h), fill=GOLD + (255,))
    Image.alpha_composite(im, over).convert("RGB").save(DOC / "map-overview.png", optimize=True)


if __name__ == "__main__":
    for name, spec in PALETTE.items():
        sprite(name, spec).save(SPR / f"actor_{name}.png")
        ring_sprite(spec[3]).save(SPR / f"ring_{name}.png")
    shadow_sprite().save(SPR / "shadow.png")
    menu_bg()
    sheet()
    banner()
    map_overview()
    for p in sorted(SPR.glob("*.png")) + sorted(DOC.glob("*.png")):
        print(p.relative_to(ROOT), p.stat().st_size // 1024, "KB")
