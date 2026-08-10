# IqraLock — Full Mac setup guide (detailed)

Do these steps **in order**.  
Use **Mac Terminal.app** for shell commands (Spotlight → “Terminal”).  
There is no special “Xcode terminal” you need — Xcode’s Report navigator only shows build logs.

| Site | URL | Use for |
|---|---|---|
| **Apple Developer** | https://developer.apple.com/account | App IDs, App Groups, Family Controls |
| **App Store Connect** | https://appstoreconnect.apple.com | App listing / TestFlight — **later** |

**Bundle IDs used by this project**

| Target | Identifier |
|---|---|
| App | `com.tahaarif.iqralock` |
| Shield Configuration extension | `com.tahaarif.iqralock.ShieldConfiguration` |
| Shield Action extension | `com.tahaarif.iqralock.ShieldAction` |
| Device Activity Monitor extension | `com.tahaarif.iqralock.DeviceActivityMonitor` |
| App Group (shared by all four) | `group.com.tahaarif.iqralock.shared` |

---

## Part 1 — Apple Developer portal

*Not App Store Connect.*

### 1.1 Confirm membership

1. Sign in at https://developer.apple.com/account  
2. Open **Membership details**  
3. Confirm **Active** Apple Developer Program  
4. Note your **Team ID**

### 1.2 Create the App Group first

You must create the group **before** you can assign it. Do **not** pick AltStore/Spotify groups if you see them.

1. **Certificates, Identifiers & Profiles** → **Identifiers**  
2. Top-left dropdown: switch from **App IDs** to **App Groups**  
3. Click **+**  
4. Description: `IqraLock Shared`  
5. Identifier: `group.com.tahaarif.iqralock.shared` (exact)  
6. **Continue** → **Register**

### 1.3 Create the four App IDs

For **each** row in the table above (the four app/extension IDs):

1. Identifiers → dropdown **App IDs** → **+**  
2. Select **App IDs** → Continue  
3. Type: **App** → Continue  
4. Description: e.g. `IqraLock`, `IqraLock Shield Configuration`, …  
5. Bundle ID: **Explicit** → paste that ID exactly  
6. Under Capabilities, enable:
   - **App Groups**
   - **Family Controls**
7. Continue → Register

### 1.4 Assign the App Group to all four App IDs

For **each** of the four App IDs:

1. Open the App ID  
2. **App Groups** → Configure / Edit  
3. Select **only** `group.com.tahaarif.iqralock.shared`  
4. Save  

If the group is missing from the list: go back to 1.2, confirm it exists under App Groups, refresh the page.

### 1.5 Request Family Controls distribution entitlement — do this early

1. Still on developer.apple.com (Identifiers / entitlements area)  
2. Request **Family Controls distribution** access for the app  
3. Justification you can paste:

> IqraLock is a self-restriction focus app. Users authorize Screen Time for individual use only and select apps to shield until they finish a daily Qur’an reading goal. Screen Time / Family Controls data never leaves the device. We need Family Controls for Managed Settings shields, Shield Configuration/Action extensions, and Device Activity midnight reset.

| Build type | When it works |
|---|---|
| Install from Xcode (Development) | Often works once capability is on the App IDs + signing works |
| **TestFlight / App Store** | Only after Apple approves **distribution** Family Controls (can take weeks) |

---

## Part 2 — Install tools on the Mac

Open **Terminal.app** (not Xcode).

```bash
# Apple command-line tools (if prompted / never installed)
xcode-select --install

# Homebrew (skip if `brew` already works)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# After Homebrew install on Apple Silicon, follow any “Add to PATH” instructions it prints,
# then open a NEW Terminal tab/window.

# XcodeGen — builds IqraLock.xcodeproj from project.yml
brew install xcodegen
```

Also required:

- **Xcode** from the Mac App Store (full app, not only CLT)  
- Open Xcode once and accept the license  

Check:

```bash
xcodebuild -version
xcodegen --version
```

---

## Part 3 — Get the right code + generate the Xcode project

### 3.1 Repo / branch

Use the branch that has bundle IDs `com.tahaarif.iqralock` (PR #2 / `cursor/iqralock-full-app-c679`).  
`main` may still have the taken ID `com.iqralock.app` until that PR is merged.

If you already cloned in Xcode:

```bash
cd /path/to/quran-scroll-mobile   # your clone path
git fetch origin
git checkout cursor/iqralock-full-app-c679
git pull origin cursor/iqralock-full-app-c679
```

Confirm you’re in the folder that contains `project.yml`:

```bash
ls project.yml
```

### 3.2 Generate and open the real project

Opening the **folder** in Xcode is not enough. You need the generated project:

```bash
xcodegen generate
open IqraLock.xcodeproj
```

Close any earlier “folder” Xcode window. Work only in `IqraLock.xcodeproj`.

If `xcodegen: command not found`, Homebrew PATH isn’t set — finish Homebrew’s PATH instructions, new Terminal tab, retry.

---

## Part 4 — Signing in Xcode

In the left sidebar, click the blue **IqraLock** project.  
For **each** of these four targets:

1. `IqraLock`  
2. `ShieldConfiguration`  
3. `ShieldAction`  
4. `DeviceActivityMonitor`  

On **Signing & Capabilities**:

1. Check **Automatically manage signing**  
2. **Team** → your Developer team  
3. Confirm Bundle Identifier matches the table at the top  
4. Confirm **Family Controls** and **App Groups** (`group.com.tahaarif.iqralock.shared`) appear  

Fix portal App IDs / App Group if Xcode reports provisioning errors.

---

## Part 5 — Run on a physical iPhone

Family Controls / Screen Time shielding **does not work in the Simulator**.

1. Unlock iPhone, connect with cable, Trust the computer if asked  
2. Enable **Developer Mode** if iOS asks:  
   Settings → Privacy & Security → Developer Mode → On → reboot  
3. Xcode top bar: select your **iPhone** (not a Simulator)  
4. Press ▶ Run (`Cmd + R`)  
5. If the phone says untrusted developer:  
   Settings → General → VPN & Device Management → trust your developer certificate  

---

## Part 6 — Test Screen Time restriction (manual script)

In the app on the phone:

1. Complete onboarding  
2. When Apple shows Screen Time access → **Allow** / **Continue**  
3. Select real apps to lock (Instagram, etc.)  
   - If you only see a fake checklist, that’s the mock picker; on device prefer the real Family Activity picker / You-tab locked-apps flow  
4. Leave IqraLock, open a shielded app → OS shield should appear  
5. From the shield: **Read now** → notification → open IqraLock → mark pages until daily goal  
6. Re-open the shielded app → should be unlocked for the rest of the day  
7. Optionally consume **emergency pass** and confirm temporary unlock  
8. You tab → **Preview lock screen** shows the in-app `3d` design (OS shield is always an approximation)

**Local testing tip:** app blocking is gated by Pro (`EntitlementGate`).  
If shields never apply during development, temporarily force Pro in `IqraLock/App/IqraLockApp.swift`:

```swift
MockPurchaseService(hasPro: true)
```

---

## Part 7 — App Store Connect + TestFlight (after device works)

Do this on https://appstoreconnect.apple.com — **not** the Identifiers screen.

1. **My Apps** → **+** → New App  
2. Bundle ID: choose `com.tahaarif.iqralock` (appears only after Part 1 App ID exists)  
3. Wait for Apple’s **Family Controls distribution** approval before expecting TestFlight/App Store installs to work with shielding  
4. In Xcode: **Product → Archive** → Distribute → App Store Connect  
5. TestFlight → Internal testing first, then External if needed  

Review notes blurb (paste when submitting):

> IqraLock is a self-restriction focus app. Users authorize Screen Time (individual) and select apps to shield until they complete a daily Qur’an reading goal. Screen Time / Family Controls data never leaves the device. The Shield Configuration / Action / Device Activity extensions implement the lock UI, “read now” notification deep link, emergency pass, and midnight reset. Subscriptions unlock the blocking mechanic and extras; the Qur’an reader remains available without a subscription.

---

## Part 8 — Optional later (not required for Screen Time proof)

- RevenueCat + App Store subscriptions  
- PostHog analytics  
- Real app icon + founders photo  
- Privacy / terms pages  
- Pixel QA against design handoff screenshots  

---

## Quick troubleshooting

| Problem | Fix |
|---|---|
| App Group list only shows AltStore/Spotify | Create `group.com.tahaarif.iqralock.shared` under Identifiers → **App Groups** first |
| `com.iqralock.app` not available | Use `com.tahaarif.iqralock` branch/PR #2 |
| No `.xcodeproj` / can’t build | Run `xcodegen generate` in Terminal from repo root |
| Simulator: no shielding | Expected — use a real iPhone |
| Signing / provisioning failed | App IDs + App Group + Family Controls missing on portal, or wrong Team |
| Apps never lock | Check Screen Time allowed; force `hasPro: true` for local tests; confirm selection persisted |

---

## Checklist (print / tick)

- [ ] Developer Program active  
- [ ] App Group `group.com.tahaarif.iqralock.shared` created  
- [ ] Four App IDs created  
- [ ] App Group assigned to all four  
- [ ] Family Controls enabled on all four  
- [ ] Family Controls **distribution** request submitted  
- [ ] Xcode + Homebrew + XcodeGen installed  
- [ ] Correct git branch with `com.tahaarif.iqralock`  
- [ ] `xcodegen generate` + open `IqraLock.xcodeproj`  
- [ ] All four targets signed with your Team  
- [ ] Run on physical iPhone  
- [ ] Screen Time allow → select apps → shield → read to goal → unlock  
- [ ] App Store Connect app created (when ready)  
- [ ] Archive → TestFlight after distribution entitlement approved  
