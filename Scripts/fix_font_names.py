#!/usr/bin/env python3
"""Rewrite the name table of the bundled Nunito faces so each declares its own identity.

The six Nunito files were cut from the variable font without regenerating their names, so all
six shipped declaring PostScript name "Nunito-ExtraLight" and family "Nunito ExtraLight". The
outlines are genuinely different weights — usWeightClass runs 400 through 900 and the advance
widths increase with weight — but iOS addresses a face by its PostScript name, so every
`Font.custom("Nunito-Bold", ...)` in the app resolved to nothing and fell back to San Francisco
at a single weight. That is why no text in the app appeared bold: not missing markup, and not
the wrong style being applied, but six fonts wearing one name.

Only the name table is touched. Glyphs, metrics and weight class are already correct.

Run from the repo root:  python Scripts/fix_font_names.py
"""

import sys
from pathlib import Path

from fontTools.ttLib import TTFont

# Google Fonts' RIBBI convention: Regular and Bold are the two styles of the "Nunito" family, so
# they can pair under one family name. Every other weight needs its own family, because a family
# can only carry four styles and iOS would otherwise have to pick between them.
FACES = {
    "Nunito-Regular.ttf":   ("Nunito",           "Regular", "Nunito-Regular",   "Regular"),
    "Nunito-Medium.ttf":    ("Nunito Medium",    "Regular", "Nunito-Medium",    "Medium"),
    "Nunito-SemiBold.ttf":  ("Nunito SemiBold",  "Regular", "Nunito-SemiBold",  "SemiBold"),
    "Nunito-Bold.ttf":      ("Nunito",           "Bold",    "Nunito-Bold",      "Bold"),
    "Nunito-ExtraBold.ttf": ("Nunito ExtraBold", "Regular", "Nunito-ExtraBold", "ExtraBold"),
    "Nunito-Black.ttf":     ("Nunito Black",     "Regular", "Nunito-Black",     "Black"),
}

# nameID: 1 family, 2 subfamily, 3 unique id, 4 full name, 6 PostScript name,
# 16 typographic family, 17 typographic subfamily.
WINDOWS = (3, 1, 0x409)
MACINTOSH = (1, 0, 0)


def rewrite(path: Path, family: str, subfamily: str, postscript: str, typo_subfamily: str) -> None:
    font = TTFont(path)
    name = font["name"]
    full = f"{family} {subfamily}" if subfamily != "Regular" else family
    version = name.getDebugName(5) or "Version 1.000"

    values = {
        1: family,
        2: subfamily,
        3: f"{version.replace('Version ', '')};{postscript}",
        4: full,
        6: postscript,
        16: "Nunito",
        17: typo_subfamily,
    }

    for name_id, value in values.items():
        for platform_id, encoding_id, language_id in (WINDOWS, MACINTOSH):
            name.setName(value, name_id, platform_id, encoding_id, language_id)

    # macStyle and fsSelection carry the bold bit independently of the name table. Left wrong,
    # a text engine asked for "Nunito" bold can synthesise a smeared fake bold on top of a face
    # that is already bold.
    is_bold = subfamily == "Bold"
    head = font["head"]
    head.macStyle = (head.macStyle | 0x01) if is_bold else (head.macStyle & ~0x01)
    os2 = font["OS/2"]
    # bit 5 bold, bit 6 regular — mutually exclusive.
    os2.fsSelection = (os2.fsSelection | 0x20) & ~0x40 if is_bold else (os2.fsSelection | 0x40) & ~0x20

    font.save(path)


def main() -> int:
    root = Path(__file__).resolve().parent.parent / "Resources" / "Fonts"
    missing = [f for f in FACES if not (root / f).exists()]
    if missing:
        print(f"missing font files: {', '.join(missing)}", file=sys.stderr)
        return 1

    for filename, (family, subfamily, postscript, typo_subfamily) in FACES.items():
        rewrite(root / filename, family, subfamily, postscript, typo_subfamily)
        print(f"{filename:24} -> PostScript {postscript!r}, family {family!r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
