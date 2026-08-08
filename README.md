# IqraLock

Islamic focus app for iOS — shields distracting apps until the user finishes their daily Qur'an reading.

**Stack:** SwiftUI · SwiftData · FamilyControls / ManagedSettings / DeviceActivity · RevenueCat (wired later) · quran.com API v4 (cached) · XcodeGen

Minimum iOS **17**.

## Repo layout

```
project.yml                 # XcodeGen source of truth (4 app targets + 2 test targets)
IqraLock/                   # App (SwiftUI)
IqraLockKit/                # Shared framework (tokens, domain, stores, Quran, Screen Time)
ShieldConfiguration/        # OS shield appearance
ShieldAction/               # Read-now notification + emergency pass
DeviceActivityMonitor/      # Midnight re-shield
Resources/Fonts/            # Nunito + Amiri
Resources/Quran/quran.sqlite
Tests/
docs/TESTFLIGHT_HUMAN_PLAN.md
```

## Mac bootstrap

```bash
brew install xcodegen
xcodegen generate
open IqraLock.xcodeproj
```

Then set your **Development Team**, enable the **Family Controls** capability on all four targets (already declared in entitlements), and ensure the App Group `group.com.tahaarif.iqralock.shared` exists for your Team ID.

```bash
xcodegen generate && xcodebuild -scheme IqraLock -destination 'generic/platform=iOS' build
xcodegen generate && xcodebuild -scheme IqraLock -destination 'platform=iOS Simulator,name=iPhone 15' test
```

Family Controls **does not work in Simulator** — Phase 4 blocking must be verified on a real device.

## Design handoff

The authoritative design package (`design_handoff_iqralock_onboarding/`) was **not present in this git repo** when the scaffold was authored. Tokens and copy were reconstructed from the implementation plan’s explicit hex values and screen list. Before visual QA:

1. Copy the handoff folder into the repo (or a sibling path).
2. Diff `IqraLockKit/DesignSystem/Tokens.swift` + `Typography.swift` against the README token table.
3. Side-by-side snapshot / PNG review for all 23 screens.

## Product decisions baked into code

| Topic | Choice in this branch |
|---|---|
| Paywall scope | `EntitlementGate` — reader free; Pro gates blocking, stats, transliteration, extras |
| Paywall dismiss | Close (×) on `2r` so navigation isn’t a hard gate |
| "18h reclaimed" | `sum(minutesRead)` |
| Daily goal | `GoalDeriver` baseline 3, boosts for frequency/Arabic, clamp 2…5 |
| Shield UI | In-app `ShieldPreviewView` is faithful `3d`; OS shield is the documented approximation |

## Licensing

- **Tanzil Uthmani** (CC BY 3.0) — attribution in About; verbatim text guarded by `arabic.sha256` + unit test.
- **Saheeh International** — bundled for offline display via quran.com resource 20.
- **Nunito / Amiri** — SIL OFL (license texts under `Resources/Fonts/`).

## What’s mocked vs real

| Area | Status |
|---|---|
| Onboarding (18 steps) + Home / Reader / Progress / You | Implemented in SwiftUI |
| Design system (tokens, chunky button, option row, scaffold) | Implemented |
| Bundled Quran SQLite (604 pages, 6236 ayahs) | Real data |
| FamilyControls / ManagedSettings | Real extension targets + kit APIs; onboarding picker mocked off-device |
| RevenueCat / PostHog | Protocol + mock / shim — enable SPM packages in `project.yml` when accounts exist |
| App icon / founders photo | Placeholders |

## Human checklist

See [docs/TESTFLIGHT_HUMAN_PLAN.md](docs/TESTFLIGHT_HUMAN_PLAN.md) for everything you must do on Apple Developer, a Mac, and TestFlight before beta.
