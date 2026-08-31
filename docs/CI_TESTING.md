# CI testing guide

What runs automatically before you push to TestFlight, and what still needs your phone.

## Workflows

| Workflow | Runner | When | Purpose |
|---|---|---|---|
| **Static Checks** | Linux (~30s) | Every push/PR on `main` and `cursor/**` | Fonts, icons, Qur'an DB, protocol wiring, test file presence |
| **iOS Build & Test** | macOS (~15 min) | After static checks pass | Compile app + extensions, run `IqraLockKitTests` on Simulator |
| **TestFlight** | macOS (~20 min) | Manual `workflow_dispatch` only | Signed archive → App Store Connect |

**Before triggering TestFlight:** open the PR checks tab and confirm both **Static Checks** and **iOS Build & Test** are green.

## What unit tests cover (Simulator)

These run in CI on every push — no device required:

| Area | Test file |
|---|---|
| Progress sync → streak | `DailyProgressSyncTests`, `ProgressIntegrationTests`, `HabitStatsTests` |
| Bathroom breaks (5 min) | `BathroomBreakTests` |
| Free-read / casual mode | `CasualReadingModeTests` |
| Prayer time math | `PrayerTimesCalculatorTests` |
| Parent PIN (Keychain) | `PINStoreTests` |
| Unlock / Screen Time factory | `UnlockCoordinatorTests`, `ScreenTimeServiceFactoryTests` |
| Qur'an data integrity | `ArabicChecksumTests` |
| Goal derivation | `GoalDeriverTests` |

Run locally on a Mac:

```bash
brew install xcodegen
xcodegen generate
python3 Scripts/validate_project.py
xcodebuild test \
  -project IqraLock.xcodeproj \
  -scheme IqraLock \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:IqraLockKitTests \
  CODE_SIGNING_ALLOWED=NO
```

## What CI cannot test (needs TestFlight + device)

| Feature | Why |
|---|---|
| Screen Time shield / unlock | `FamilyControls` traps on Simulator |
| OS lock-screen shield UI | Extension only runs on device |
| Push notifications (prayer, streak) | Requires notification permission on device |
| Bathroom break auto re-shield | `DeviceActivity` monitor needs device |
| Parent PIN UI flow | Keychain + sheets — unit-tested logic only |
| StoreKit purchases | Mocked in debug; real IAP needs App Store Connect |

Use the [TestFlight human plan](TESTFLIGHT_HUMAN_PLAN.md) for device verification after CI is green.

## Adding tests for new features

1. Add a test file under `Tests/IqraLockKitTests/`
2. Register it in `Scripts/validate_project.py` → `check_feature_tests()` so CI fails if the file is removed
3. If you add `NotificationScheduling` methods, update every conformer (`LocalNotificationScheduler`, `NotificationTestDouble`)

## Snapshot tests

`IqraLockSnapshotTests` runs non-blocking in CI until reference images are committed from a Mac. Do not rely on it for merge gating yet.
