# Agent pipeline for IqraLock

This document is the repo-specific playbook for humans and cloud agents. It describes what must be true before a PR merges, and which bugs each gate is meant to prevent.

## Risk classes

| Class | Examples in this repo | Primary gate |
|-------|----------------------|--------------|
| **Algorithm / date math** | `PrayerTimesCalculator`, equation of time, Asr shadow formula | Golden hour-range unit tests |
| **User offsets on algorithms** | `PrayerTimeAdjustments`, `PrayerTimesResolver` | Offset + resolver unit tests |
| **Cross-process state** | `AppGroupStore`, `PrayerCitySelection`, extensions reading shared keys | Round-trip contract tests (write → read) |
| **Notification scheduling** | `NotificationScheduling.schedulePrayerNotifications` | Tests assert resolver output, stable IDs |
| **SwiftUI side effects** | `modelContext.insert` during `body`, duplicate logs | Code review; no mutation in `body` |
| **Visual / contrast** | City picker, settings sheets | Snapshot tests (currently non-blocking) |
| **Platform-only** | Screen Time shields, delivered notifications, Keychain UI | Device TestFlight smoke (`docs/TESTFLIGHT_HUMAN_PLAN.md`) |

## Invariants (do not break)

### Prayer times

- All five prayers (`Fajr` … `Isha`) must exist and be on the same calendar day.
- Times must be strictly chronological: Fajr < Dhuhr < Asr < Maghrib < Isha.
- For Atlanta on 2026-09-01 (America/New_York): Fajr ~04–07, Dhuhr ~12–14, **Asr ≥ 12:00 (never AM)**, Maghrib evening, Isha evening.
- Equation of time: normalize angle deltas to **(−180°, 180°]** — never `% 360` on small negative values.
- User adjustments are **minute offsets** on calculated times; tracker and notifications must both use `PrayerTimesResolver`.

### App Group

- Every new `AppGroupStore.Key` must appear in `resetAllForDebug()` (enforced by `validate_project.py`).
- Every write path must have a reader test: save in one place, load in the consumer (You tab → Progress tab pattern).

### SwiftUI

- No `modelContext.insert`, `save()`, or other mutations inside `var body` or `ForEach` without an idempotency guard.
- Cross-tab refresh: bump `prayerScheduleVersion` (or equivalent) when App Group settings change.

### Notifications

- Prayer notification IDs stay stable: `prayer_fajr` … `prayer_isha`.
- Scheduled times must use the same resolver as the Progress tracker (including adjustments).

## Required proof before merge

| If you change… | You must… |
|----------------|-----------|
| `PrayerTimesCalculator.swift` | Update `PrayerTimesCalculatorTests.swift` with domain assertions (hour ranges, ordering, same day) |
| `PrayerTimeAdjustments.swift` | Update `PrayerTimeAdjustmentsTests.swift` (offsets, round-trip, resolver) |
| `PrayerProgressSync.swift` / streak changes | Update `PrayerProgressSyncTests.swift` |
| `PrayerCityCatalog.swift` / `PrayerCitySelection` | Update `PrayerCityCatalogTests.swift` |
| `AppGroupStore.swift` | Update a contract test that round-trips the changed key |
| `NotificationScheduling.swift` | Update `PrayerNotificationSchedulingTests.swift` |
| `ShieldLayoutPresentation.swift` / `ShieldLayoutMode.swift` | Update `ShieldLayoutPresentationTests.swift` |
| Settings UI only (colors, layout) | Snapshot or manual device check |

`Scripts/validate_project.py --pr-diff` enforces the source → test file pairs automatically in CI.

## Agent workflow (recommended)

1. **Plan** — List invariants and which test files will change.
2. **Test first** — Add or extend failing tests for risky logic before fixing implementation.
3. **Small diff** — One feature per branch; avoid touching calculator + UI + notifications in one unstructured pass.
4. **Static CI** — `validate_project.py` + `--pr-diff` on Linux (~30s).
5. **Build CI** — `ios.yml` unit tests on macOS.
6. **Review** — Scan for SwiftUI side effects and App Group reader/writer mismatch.
7. **Device smoke** — For prayer notifications, city picker, or shields: follow TestFlight checklist.

## CI gates

| Workflow | What it catches |
|----------|-----------------|
| `static-checks.yml` | Missing assets, App Group reset gaps, protocol conformers, **risky diff without tests** |
| `ios.yml` | Compile errors, unit test failures |
| Snapshot tests | UI regressions (non-blocking today) |

Local:

```bash
python3 Scripts/validate_project.py
python3 Scripts/validate_project.py --pr-diff --base origin/main
```

## Device smoke (not automatable in CI)

After prayer-related changes:

- [ ] Choose city → Progress shows five times in order
- [ ] Adjust one prayer → Progress and notification pending time match
- [ ] Reset adjustments → back to calculated times
- [ ] Log prayer → persists after app restart

See `docs/TESTFLIGHT_HUMAN_PLAN.md` for full release steps.

## Known gaps (phase 2)

- Golden JSON vectors for prayer times from an external reference
- Blocking snapshot tests for settings sheets
- Lint rule for SwiftData mutations in `body`
- Property-based fuzz on prayer ordering after large offsets
