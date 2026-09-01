#!/usr/bin/env python3
"""Static project validation — runs on Linux CI without Xcode.

Catches resource and wiring problems before the expensive macOS build:
- bundled fonts, icons, Qur'an database
- App Group keys included in debug reset
- NotificationScheduling conformers implement every protocol method
- test files exist for new feature areas
"""

from __future__ import annotations

import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)


def ok(msg: str) -> None:
    print(f"  ok   {msg}")


def check_fonts() -> list[str]:
    errors: list[str] = []
    fonts = ROOT / "Resources" / "Fonts"
    expected = [
        "Nunito-Regular.ttf", "Nunito-Bold.ttf", "Nunito-Black.ttf",
        "Amiri-Regular.ttf", "Amiri-Bold.ttf",
    ]
    for name in expected:
        if not (fonts / name).exists():
            errors.append(f"missing font {name}")
        else:
            ok(f"font {name}")
    return errors


def check_icons() -> list[str]:
    errors: list[str] = []
    icon_swift = ROOT / "IqraLockKit" / "DesignSystem" / "IQIcon.swift"
    text = icon_swift.read_text()
    cases = re.findall(r'case \w+ = "(iq-[^"]+)"', text)
    assets = ROOT / "Resources" / "Icons.xcassets"
    for raw in cases:
        png = assets / f"{raw}.imageset" / f"{raw}.png"
        if not png.exists():
            errors.append(f"missing icon asset {raw}.png")
        else:
            ok(f"icon {raw}")
    return errors


def check_quran_db() -> list[str]:
    errors: list[str] = []
    db = ROOT / "Resources" / "Quran" / "quran.sqlite"
    if not db.exists():
        return [f"missing {db.relative_to(ROOT)}"]
    ok("quran.sqlite present")
    con = sqlite3.connect(db)
    try:
        (count,) = con.execute("SELECT COUNT(*) FROM ayahs").fetchone()
        if count < 6000:
            errors.append(f"ayahs table has only {count} rows, expected ~6236")
        else:
            ok(f"ayahs table has {count} rows")
        pages = con.execute("SELECT COUNT(DISTINCT page) FROM ayahs").fetchone()[0]
        if pages != 604:
            errors.append(f"expected 604 pages, found {pages}")
        else:
            ok("604 mushaf pages")
    finally:
        con.close()
    return errors


def check_app_group_reset_keys() -> list[str]:
    errors: list[str] = []
    store = (ROOT / "IqraLockKit" / "SharedState" / "AppGroupStore.swift").read_text()
    key_block = re.search(r"enum Key \{([^}]+)\}", store, re.S)
    reset_block = re.search(r"resetAllForDebug\(\)[^{]+\{([^}]+)\}", store, re.S)
    if not key_block or not reset_block:
        return ["could not parse AppGroupStore keys or resetAllForDebug"]
    declared = set(re.findall(r"static let (\w+)", key_block.group(1)))
    reset = set(re.findall(r"Key\.(\w+)", reset_block.group(1)))
    # Keys that intentionally survive debug reset
    optional = {"khatmRecords", "khatmStartedAt", "totalPagesRead", "khatmCount", "sittingsToday"}
    missing = declared - reset - optional
    if missing:
        errors.append(f"AppGroupStore.Key not in resetAllForDebug: {sorted(missing)}")
    else:
        ok("AppGroupStore debug reset covers keys")
    return errors


def check_notification_conformers() -> list[str]:
    errors: list[str] = []
    protocol_file = (ROOT / "IqraLockKit" / "Notifications" / "NotificationScheduling.swift").read_text()
    methods = re.findall(r"func (\w+)\(", protocol_file.split("protocol NotificationScheduling")[1].split("}")[0])
    conformer_pattern = re.compile(
        r"\b(?:public\s+|private\s+|final\s+)*class\s+\w+\s*:\s*NotificationScheduling\b"
    )
    for swift_file in ROOT.rglob("*.swift"):
        text = swift_file.read_text()
        if not conformer_pattern.search(text):
            continue
        for method in methods:
            if f"func {method}(" not in text:
                errors.append(f"{swift_file.relative_to(ROOT)} missing NotificationScheduling.{method}")
    if not errors:
        ok("NotificationScheduling conformers complete")
    return errors


def check_feature_tests() -> list[str]:
    errors: list[str] = []
    tests = ROOT / "Tests" / "IqraLockKitTests"
    required = [
        "DailyProgressSyncTests.swift",
        "BathroomBreakTests.swift",
        "CasualReadingModeTests.swift",
        "PrayerTimesCalculatorTests.swift",
        "PrayerCityCatalogTests.swift",
        "PINStoreTests.swift",
        "ProgressIntegrationTests.swift",
    ]
    for name in required:
        if not (tests / name).exists():
            errors.append(f"missing test file {name}")
        else:
            ok(f"test {name}")
    return errors


def main() -> int:
    print("Validating IqraLock project…\n")
    sections = [
        ("Fonts", check_fonts),
        ("Icons", check_icons),
        ("Qur'an database", check_quran_db),
        ("App Group keys", check_app_group_reset_keys),
        ("Notification protocol", check_notification_conformers),
        ("Feature tests", check_feature_tests),
    ]
    all_errors: list[str] = []
    for title, fn in sections:
        print(f"[{title}]")
        all_errors.extend(fn())
        print()

    if all_errors:
        print(f"\n{len(all_errors)} validation error(s):", file=sys.stderr)
        for err in all_errors:
            fail(err)
        return 1

    print("All static checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
