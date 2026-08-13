# TestFlight from Windows — what you need to do

Everything here is done in a **web browser**. You do not need a Mac at any point, and you
do not need to plug in your phone.

The reason no Mac is required: the workflow signs with an **App Store Connect API key** plus
`-allowProvisioningUpdates`, so Xcode on the CI runner creates the distribution certificate
and all four provisioning profiles itself. The usual alternative — exporting a `.p12` from
Keychain Access — is the part that would have needed a Mac.

---

## 1. Register the identifiers (developer.apple.com)

Certificates, Identifiers & Profiles → Identifiers. You need **four** App IDs, each with
**Family Controls** and the **App Group** enabled:

| App ID | |
|---|---|
| `com.tahaarif.iqralock` | the app |
| `com.tahaarif.iqralock.ShieldConfiguration` | |
| `com.tahaarif.iqralock.ShieldAction` | |
| `com.tahaarif.iqralock.DeviceActivityMonitor` | |

App Group: `group.com.tahaarif.iqralock.shared` — must match `AppGroupID.identifier`, and must
be enabled on all four.

> Family Controls must be enabled on **every** target, not just the app. If an extension is
> missing it, the archive step fails at signing rather than at build.

Note your **Team ID** from Membership details.

## 2. Create the App Store Connect app record

App Store Connect → Apps → **+** → New App. Bundle ID `com.tahaarif.iqralock`. Set platform,
name, primary language and category. Screenshots can wait — TestFlight doesn't need them.

Without this record the upload step fails with an unhelpful "no suitable application" error.

## 3. Create the App Store Connect API key

App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** →
Team Keys → **+**.

- Access role: **App Manager** (Developer is not enough to upload builds)
- Download the `.p8` file — **you only get one chance**; Apple will not let you download it again
- Note the **Key ID** and the **Issuer ID** shown on that page

## 4. Add four GitHub secrets

Repo → Settings → Secrets and variables → Actions → New repository secret.

| Secret | Value |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | the Key ID, e.g. `A1B2C3D4E5` |
| `APP_STORE_CONNECT_ISSUER_ID` | the Issuer ID (a UUID) |
| `APP_STORE_CONNECT_PRIVATE_KEY` | the **entire contents** of the `.p8`, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |
| `DEVELOPMENT_TEAM` | your Team ID, e.g. `AB12CD34EF` |

Open the `.p8` in Notepad and paste all of it, newlines included. A truncated key fails at
archive time with an authentication error.

## 5. Run it

Actions → **TestFlight** → Run workflow. About 10–20 minutes, then 5–15 minutes of Apple-side
processing before it appears on your phone.

Install **TestFlight** from the App Store on your device and sign in with the same Apple ID
that owns the developer account. Builds appear automatically; no cable, no reinstall.

---

## Your loop after this

```
edit on Windows → push → Actions → TestFlight → build lands on phone
```

Roughly 20–30 minutes end to end. Slower than a Simulator, so:

- **Logic and compile errors** → the `iOS Build & Test` workflow, ~5 minutes, every push
- **Shield / blocking behaviour** → TestFlight, because FamilyControls cannot run in a Simulator
- **UI iteration** → genuinely painful this way; a rented cloud Mac by the hour is better if you
  are doing visual work

## Re-testing onboarding without reinstalling

Debug builds have **You → Debug → Reset to first run**, which clears the onboarding flag, the
SwiftData store and the App Group in one go.

Caveat: TestFlight builds are **Release**, so `#if DEBUG` is compiled out and the button is not
there. To get it on a device, either build Debug to the device from a Mac, or temporarily change
the archive step's `-configuration Release` to `Debug` (do not ship that).

## OUTSTANDING: the certificate limit

**Every CI run creates a new signing certificate, and the account will fill up.**

The runner's keychain starts empty each time, so `-allowProvisioningUpdates` cannot reuse an
existing signing identity and mints a fresh one instead. This first bit after about ten builds:

```
error: Choose a certificate to revoke. Your account has reached the maximum number of certificates.
error: No profiles for 'com.tahaarif.iqralock' were found
```

**Stopgap** (browser only, no Mac needed — a phone works): developer.apple.com → Certificates,
Identifiers & Profiles → Certificates → revoke the Apple Distribution certificates created by CI,
keeping one. Don't revoke one your local Xcode is using, or one tied to a build already on the
App Store.

**Permanent fix** (needs a Mac once):

1. Keychain Access → your Apple Distribution certificate → right-click → Export → `.p12` with a
   password.
2. `base64 -i cert.p12 | pbcopy`
3. Add two GitHub secrets: `SIGNING_CERTIFICATE_P12` (the base64) and
   `SIGNING_CERTIFICATE_PASSWORD`.
4. Add a step to `testflight.yml` before Archive that creates a temporary keychain, imports the
   `.p12`, and unlocks it. Xcode then reuses that identity instead of creating one, and only
   provisioning profiles are fetched automatically.

Until step 4 exists, expect to revoke certificates roughly every ten builds.

## Things that will bite

- **Build numbers are permanent.** The workflow uses `github.run_number`, which only increases.
  Never lower it — App Store Connect rejects a build number it has already seen.
- **Family Controls distribution approval** must be granted for TestFlight, not just development.
  You have it; if a signing error mentions the entitlement, check it is on all four App IDs.
- **Sandbox purchases on TestFlight** use the real StoreKit sandbox, not the local `.storekit`
  file. Create a Sandbox Apple ID under Users and Access → Sandbox Testers. Trials run on
  accelerated sandbox timing (a 3-day trial expires in minutes).
- **`app-store-connect` export method** is the Xcode 15.3+ name. On an older Xcode it must be
  `app-store` — change it in `.github/workflows/testflight.yml` if the export step rejects it.
