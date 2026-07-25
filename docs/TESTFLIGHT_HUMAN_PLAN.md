# Your personal plan — IqraLock to TestFlight

This is everything **only you** can do (accounts, Apple approval, Mac signing, hardware). The code scaffold is already in the repo; none of the steps below can be finished by the cloud agent alone.

Do them in this order. Items marked **BLOCKER** stop TestFlight / App Store if skipped.

---

## 0. Before you touch Xcode (do today)

### 0.1 Apple Developer Program — **BLOCKER**
- [ ] Confirm you have an active [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/yr) on the team that will ship IqraLock.
- [ ] Note your **Team ID** (Membership details). You’ll paste it into Xcode / `DEVELOPMENT_TEAM`.

### 0.2 Request Family Controls distribution entitlement — **BLOCKER**
- [ ] In [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles → Identifiers → your App ID → capability **Family Controls**.
- [ ] Submit Apple’s **Family Controls distribution** request form (distribution entitlement). Development builds can work once the capability is on the App ID; **TestFlight and App Store are blocked until Apple approves distribution**.
- [ ] Justification to use: parental-control-style **self-restriction** app; **individual** authorization only; Screen Time data never leaves the device; used to shield user-selected apps until daily Qur’an reading is complete.
- [ ] Expect multi-week latency — submit before polishing UI.

### 0.3 Create App IDs & App Group
- [ ] App ID: `com.tahaarif.iqralock` (or your chosen reverse-DNS — if you change it, update `project.yml` + all entitlements + App Group string).
- [ ] Extension App IDs:
  - `com.tahaarif.iqralock.ShieldConfiguration`
  - `com.tahaarif.iqralock.ShieldAction`
  - `com.tahaarif.iqralock.DeviceActivityMonitor`
- [ ] App Group: `group.com.tahaarif.iqralock.shared` (must match `AppGroupID.identifier`) enabled on **all four** App IDs.
- [ ] Enable **Family Controls** on all four App IDs.

### 0.4 App Store Connect app record
- [ ] Create the app (iOS, bundle id matching `project.yml`).
- [ ] Skip filling screenshots until you have device builds; do set primary language and category (Lifestyle / Education — pick one and stay consistent).

### 0.5 RevenueCat + products
- [ ] Create a RevenueCat project; note the iOS API key.
- [ ] In App Store Connect → Subscriptions: group “IqraLock Pro” with:
  - Annual `com.tahaarif.iqralock.pro.annual` — $29.99, 3-day free trial
  - Weekly `com.tahaarif.iqralock.pro.weekly` — $2.99
- [ ] Entitlement id: `pro` (matches plan).
- [ ] Link products in RevenueCat; create Offering `default` (and a second offering later for Experiments).
- [ ] Uncomment the RevenueCat SPM package in `project.yml` and replace `MockPurchaseService` with a real implementation when ready.

### 0.6 PostHog (analytics)
- [ ] Create a PostHog project; note the API key + host.
- [ ] Uncomment PostHog SPM in `project.yml` when ready; replace `NoopAnalytics` in `AppModel` for Release.

### 0.7 Design handoff into the repo
- [ ] Copy `design_handoff_iqralock_onboarding/` into the project (it was missing from git when the scaffold was built).
- [ ] Diff README token table → `Tokens.swift` / `Typography.swift` and fix any drift.
- [ ] Keep `screenshots/*.png` for visual acceptance.

### 0.8 Legal / copy decisions (before you show the paywall to strangers)
- [ ] Confirm **10% sadaqah jariyah** is a real program you can honor (or change the paywall copy).
- [ ] Confirm or remove **“#1 Muslim Focus App”** (App Review / ads may challenge unsubstantiated superlatives).
- [ ] Decide privacy policy + terms URLs (You tab currently points at `https://iqralock.app/privacy` and `/terms` — publish real pages).
- [ ] Confirm paywall scope: code defaults to **reader free / Pro = blocking + extras** via `EntitlementGate`. Change that one type if you want a different split.

---

## 1. First Mac build (day you have a Mac)

### 1.1 Generate the Xcode project
```bash
brew install xcodegen
cd /path/to/IqraLock
xcodegen generate
open IqraLock.xcodeproj
```

### 1.2 Signing
- [ ] Select each of the 4 targets → Signing & Capabilities → your Team.
- [ ] Confirm entitlements files attach (Family Controls + App Group).
- [ ] Set `DEVELOPMENT_TEAM` in project settings or a private `Local.xcconfig` (do not commit secrets).

### 1.3 Build
```bash
xcodegen generate && xcodebuild -scheme IqraLock -destination 'generic/platform=iOS' build
```
- [ ] Fix any signing / provisioning errors Xcode surfaces (usually App Group or Family Controls not enabled on the App ID).

### 1.4 Unit tests (Simulator OK)
```bash
xcodebuild -scheme IqraLock -destination 'platform=iOS Simulator,name=iPhone 16' test
```
- [ ] HabitStats, GoalDeriver, ProjectionCalculator, EntitlementGate, UnlockCoordinator, Arabic checksum should run once `quran.sqlite` is in the test host bundle.

### 1.5 Snapshot references
- [ ] In `ComponentSnapshotTests`, temporarily set `record` to `.all`, run tests, commit `__Snapshots__`, set back to `.never`.
- [ ] Expand snapshot coverage to all 23 screens when visually matching the handoff PNGs.

---

## 2. Device setup for Screen Time (required for the core loop)

Family Controls **cannot** be tested in Simulator.

- [ ] Physical iPhone on iOS 17+.
- [ ] Install a Development-signed build from Xcode.
- [ ] Onboarding → allow Screen Time when the system prompt appears.
- [ ] Select real apps (Instagram, etc.) in the FamilyActivityPicker (wire `FamilyActivityPickerScreen` into the `appPicker` step if you still see the mock list — mock is intentional for Simulator).
- [ ] Manual script:
  1. Open a shielded app → OS shield shows title/colors/buttons.
  2. Tap **Read now** → notification appears → open app → reader.
  3. Mark pages until goal → shield clears.
  4. Use debug short `DeviceActivitySchedule` (add under `#if DEBUG`) to prove re-shield without waiting for midnight.
  5. Consume an emergency pass → temporary unlock → re-shield.

---

## 3. Content & brand assets you must supply

- [ ] App icon: اقرأ in Amiri Bold on `#6B3F1E → #38200F` with gold crescent — all App Store sizes (replace empty `AppIcon.appiconset`).
- [ ] Founders / social-proof photo for onboarding rating screen (`2p` placeholder).
- [ ] Optional: marketing screenshots once UI matches handoff.
- [ ] On-device check of diacritic-heavy ayahs (e.g. 2:1–5, 27:30) with Amiri — shaping bugs are content bugs.

---

## 4. Purchases sandbox

- [ ] Use `Resources/StoreKit/IqraLock.storekit` in the Run scheme (already referenced in `project.yml`).
- [ ] Sandbox Apple ID: start trial, renew, cancel, restore.
- [ ] Confirm price strings on `2r` come from the store / RevenueCat Offering (not hard-coded) once RC is wired.
- [ ] Attach Paid Apps Agreement + banking/tax in App Store Connect — **BLOCKER** for IAP on TestFlight in some cases / always for sale.

---

## 5. Upload to TestFlight

- [ ] Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` as needed; regenerate.
- [ ] Archive in Xcode (Product → Archive) with **Release** + distribution-capable Family Controls provisioning (after Apple approval).
- [ ] Upload via Organizer → App Store Connect.
- [ ] Fill Export Compliance, Content Rights, Advertising Identifier (No ATT / no IDFA).
- [ ] Add TestFlight “What to Test” notes; mention Screen Time permission steps.
- [ ] Internal testing first (App Store Connect Users) — no review.
- [ ] External beta → submit Beta App Review. Include Family Controls justification in review notes: self-restriction, individual auth, data on-device only.

### Review notes blurb (paste-ready)

> IqraLock is a self-restriction focus app. Users authorize Screen Time (individual) and select apps to shield until they complete a daily Qur’an reading goal. Screen Time / Family Controls data never leaves the device. The Shield Configuration / Action / Device Activity extensions implement the lock UI, “read now” notification deep link, emergency pass, and midnight reset. Subscriptions unlock the blocking mechanic and extras; the Qur’an reader (Arabic + Saheeh International) remains available without a subscription.

---

## 6. Pre-beta quality gate

- [ ] Onboarding end-to-end on device; draft resume after force-quit.
- [ ] Airplane mode: Arabic + bundled translation render.
- [ ] Translation switch (if Pro) hits API + cache.
- [ ] Notifications: daily reminder, streak-at-risk 20:00, unlock confirmation, shield deep link.
- [ ] VoiceOver pass on progress ring, week dots, chart, option rows.
- [ ] iPhone SE → Pro Max layout smoke test.
- [ ] Privacy Nutrition Labels in App Store Connect match `PrivacyInfo.xcprivacy` + PostHog/RevenueCat.
- [ ] About screen shows Tanzil link + copyright + Saheeh International credit.

---

## 7. Parallel track while waiting on Apple

You can do all of this **while** Family Controls distribution is pending:

1. Visual QA against handoff PNGs (no entitlement needed).
2. Snapshot suite + unit tests.
3. RevenueCat + paywall copy finalization.
4. Privacy/terms pages.
5. Icon + founders photo.
6. PostHog funnel dashboard (`onboarding_step_viewed`, etc.).
7. Internal TestFlight **without** verifying shields (or with development entitlement only, if Apple has granted dev but not distribution yet).

You **cannot** ship external TestFlight / App Store until the distribution entitlement is approved.

---

## 8. Suggested personal checklist order (compressed)

| # | Action | Depends on |
|---|---|---|
| 1 | Submit Family Controls distribution request | Developer account |
| 2 | Create App IDs + App Group + ASC app | Developer account |
| 3 | Drop design handoff into repo; fix token drift | Your design files |
| 4 | Mac: `xcodegen` + Team signing + first run | Mac + certs |
| 5 | Device: Screen Time happy path | Physical iPhone + capability |
| 6 | ASC subscriptions + RevenueCat | ASC agreements |
| 7 | Assets, privacy URLs, copy decisions | You |
| 8 | Archive → Internal TestFlight | Signing |
| 9 | External TestFlight after entitlement approval | Apple approval |
| 10 | Iterate with beta testers on the blocking loop | External testers |

---

## Contact / accounts used in this cloud run

- GitHub repo: `tahaarif3/quran-scroll-mobile`
- Bundle prefix in code: `com.tahaarif.iqralock.*`
- App Group: `group.com.tahaarif.iqralock.shared`

If you change bundle IDs, change them in `project.yml`, all `.entitlements`, and `AppGroupID.swift` together, then regenerate with XcodeGen.
