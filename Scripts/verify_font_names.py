#!/usr/bin/env python3
"""Fail the build if a bundled font's PostScript name doesn't match its filename.

`Font.custom` and `UIFont(name:)` address a face by its PostScript name, and both fail *quietly*
— SwiftUI falls back to San Francisco and reports nothing. So a font whose internal name doesn't
match the name the code asks for produces an app that looks subtly wrong everywhere and blames
nothing, which is exactly what shipped: six Nunito weights all declaring "Nunito-ExtraLight",
so every weight the design system asked for resolved to the same system fallback and no text in
the app was bold.

The invariant this enforces is the one the app actually depends on: UIAppFonts lists filenames,
IQFontStyle.postScriptName produces the matching stem, so stem == PostScript name.

Deliberately dependency-free — it parses the name table directly rather than importing fontTools,
so it runs on a bare CI runner with no pip step.
"""

import struct
import sys
from pathlib import Path

NAME_ID_POSTSCRIPT = 6


def postscript_name(path: Path) -> str | None:
    data = path.read_bytes()
    if len(data) < 12:
        return None
    num_tables = struct.unpack(">H", data[4:6])[0]

    tables = {}
    for index in range(num_tables):
        entry = 12 + 16 * index
        if entry + 16 > len(data):
            return None
        tag = data[entry : entry + 4].decode("latin-1")
        offset, length = struct.unpack(">II", data[entry + 8 : entry + 16])
        tables[tag] = (offset, length)

    if "name" not in tables:
        return None
    table_offset, _ = tables["name"]
    _, count, storage_offset = struct.unpack(">HHH", data[table_offset : table_offset + 6])

    for index in range(count):
        record = table_offset + 6 + 12 * index
        platform_id, _, _, name_id, length, offset = struct.unpack(
            ">HHHHHH", data[record : record + 12]
        )
        if name_id != NAME_ID_POSTSCRIPT:
            continue
        start = table_offset + storage_offset + offset
        raw = data[start : start + length]
        try:
            return raw.decode("utf-16-be") if platform_id == 3 else raw.decode("latin-1")
        except UnicodeDecodeError:
            continue
    return None


def main() -> int:
    fonts = Path(__file__).resolve().parent.parent / "Resources" / "Fonts"
    files = sorted(fonts.glob("*.ttf"))
    if not files:
        print(f"no fonts found in {fonts}", file=sys.stderr)
        return 1

    failures = []
    for path in files:
        declared = postscript_name(path)
        if declared != path.stem:
            failures.append((path.name, declared))
        print(f"  {path.name:24} PostScript name: {declared!r}")

    if failures:
        print("\nFont name mismatch — these faces are unreachable from Swift:", file=sys.stderr)
        for filename, declared in failures:
            print(f"  {filename}: declares {declared!r}, code asks for {Path(filename).stem!r}",
                  file=sys.stderr)
        print("\nRun: python Scripts/fix_font_names.py", file=sys.stderr)
        return 1

    print(f"\n{len(files)} fonts verified — every PostScript name matches its filename.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
