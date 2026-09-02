#!/usr/bin/env python3
"""Static project validation — runs on Linux CI without Xcode.

Catches resource and wiring problems before the expensive macOS build:
- bundled fonts, icons, Qur'an database
- App Group keys included in debug reset
- NotificationScheduling conformers implement every protocol method
- test files exist for new feature areas
- risky source files changed in a PR must touch paired test files (--pr-diff)
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# When a risky source file changes, at least one paired test file must change too.
RISKY_SOURCE_TO_TESTS: dict[str, list[str]] = {
    "IqraLockKit/Prayer/PrayerTimesCalculator.swift": [
        "Tests/IqraLockKitTests/PrayerTimesCalculatorTests.swift",
    ],
    "IqraLockKit/Prayer/PrayerTimeAdjustments.swift": [
        "Tests/IqraLockKitTests/PrayerTimeAdjustmentsTests.swift",
    ],
    "IqraLockKit/Habit/DailyProgressSync.swift": [
        "Tests/IqraLockKitTests/DailyProgressSyncTests.swift",
        "Tests/IqraLockKitTests/PrayerProgressSyncTests.swift",
        "Tests/IqraLockKitTests/ProgressIntegrationTests.swift",
    ],
    "IqraLockKit/Habit/PrayerProgressSync.swift": [
        "Tests/IqraLockKitTests/PrayerProgressSyncTests.swift",
    ],
    "IqraLockKit/Prayer/PrayerCityCatalog.swift": [
        "Tests/IqraLockKitTests/PrayerCityCatalogTests.swift",
    ],
    "IqraLockKit/SharedState/AppGroupStore.swift": [
        "Tests/IqraLockKitTests/ShieldLayoutPresentationTests.swift",
        "Tests/IqraLockKitTests/PrayerTimeAdjustmentsTests.swift",
        "Tests/IqraLockKitTests/PrayerCityCatalogTests.swift",
        "Tests/IqraLockKitTests/DailyProgressSyncTests.swift",
    ],
    "IqraLockKit/Notifications/NotificationScheduling.swift": [
        "Tests/IqraLockKitTests/PrayerNotificationSchedulingTests.swift",
    ],
    "IqraLockKit/Quran/ShieldLayoutPresentation.swift": [
        "Tests/IqraLockKitTests/ShieldLayoutPresentationTests.swift",
    ],
    "IqraLockKit/ScreenTime/ShieldLayoutMode.swift": [
        "Tests/IqraLockKitTests/ShieldLayoutPresentationTests.swift",
    ],
}


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)


def ok(msg: str) -> None:
    print(f"  ok   {msg}")


def git_changed_files(base: str) -> set[str]:
    """Return repo-relative paths changed between base and HEAD."""
    for merge_base in (base, f"origin/{base}"):
        result = subprocess.run(
            ["git", "merge-base", merge_base, "HEAD"],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            diff_base = result.stdout.strip()
            break
    else:
        diff_base = base

    result = subprocess.run(
        ["git", "diff", "--name-only", f"{diff_base}...HEAD"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        fail(f"git diff failed: {result.stderr.strip()}")
        return set()
    return {line.strip() for line in result.stdout.splitlines() if line.strip()}


def check_pr_test_pairs(base: str) -> list[str]:
    errors: list[str] = []
    changed = git_changed_files(base)
    if not changed:
        ok("no changed files (skipping risky-pair check)")
        return errors

    print(f"  diff base: {base} ({len(changed)} changed file(s))")
    for source, required_tests in RISKY_SOURCE_TO_TESTS.items():
        if source not in changed:
            continue
        if any(test in changed for test in required_tests):
            ok(f"{source} → test updated")
        else:
            tests_list = ", ".join(required_tests)
            errors.append(
                f"{source} changed but no paired test file changed "
                f"(expected one of: {tests_list})"
            )
    if not errors and not any(s in changed for s in RISKY_SOURCE_TO_TESTS):
        ok("no risky source files in diff")
    return errors


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
        "PrayerTimeAdjustmentsTests.swift",
        "PrayerProgressSyncTests.swift",
        "PrayerCityCatalogTests.swift",
        "ShieldLayoutPresentationTests.swift",
        "PrayerNotificationSchedulingTests.swift",
        "PrayerLogTests.swift",
        "PrayerProgressSyncTests.swift",
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
    parser = argparse.ArgumentParser(description="Validate IqraLock project wiring and tests.")
    parser.add_argument(
        "--pr-diff",
        action="store_true",
        help="Fail if risky source files changed without paired test file updates.",
    )
    parser.add_argument(
        "--base",
        default="main",
        help="Git base ref for --pr-diff (default: main).",
    )
    args = parser.parse_args()

    print("Validating IqraLock project…\n")
    sections: list[tuple[str, Callable[[], list[str]]]] = [
        ("Fonts", check_fonts),
        ("Icons", check_icons),
        ("Qur'an database", check_quran_db),
        ("App Group keys", check_app_group_reset_keys),
        ("Notification protocol", check_notification_conformers),
        ("Feature tests", check_feature_tests),
    ]
    if args.pr_diff:
        sections.append(("PR risky-pair diff", lambda: check_pr_test_pairs(args.base)))

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
