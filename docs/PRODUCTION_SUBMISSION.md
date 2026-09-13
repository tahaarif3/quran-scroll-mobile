# Production App Store submission — what only you can finish

The code for a production flavor lives on `cursor/production-submission-fa08`. It uses **real StoreKit 2**, no mock paywall, and no internal reset menu.

The cloud agent cannot: sign with your team, create App Store Connect products, accept legal agreements, request entitlements, publish your website, or upload a build. Those steps are below.

Do them in this order. Items marked **BLOCKER** stop TestFlight (distribution) or App Review.

---

## 1. Family Controls distribution — BLOCKER

Apple’s form: [Request a Family Controls entitlement](https://developer.apple.com/contact/request/family-controls-distribution)

You need the **distribution** entitlement (not only development) on **four** App IDs:

| App ID | Target |
|---|---|
| `com.tahaarif.iqralock` | main app |
| `com.tahaarif.iqralock.ShieldConfiguration` | shield UI |
| `com.tahaarif.iqralock.ShieldAction` | shield buttons |
| `com.tahaarif.iqralock.DeviceActivityMonitor` | midnight / unlock timer |

In Certificates, Identifiers & Profiles → each identifier → enable **Family Controls** and App Group `group.com.tahaarif.iqralock.shared`.

Suggested justification:

> IqraLock is a self-restriction app. The user authorizes Family Controls for themselves (individual authorization, not a parent/child guardian pair). Selected apps are shielded until the user reads Qur’an. Tokens stay on device. We do not read app names or usage.

Approval can take days to weeks. TestFlight signing fails until this is granted.

---

## 2. Publish the iOS privacy policy and terms — BLOCKER

The live site at `https://iqralock.app/privacy` must **not** describe an Android app.

Repo files to upload, as-is, to your host:

- [docs/privacy.html](privacy.html) → `https://iqralock.app/privacy`
- [docs/terms.html](terms.html) → `https://iqralock.app/terms`

If the site is WordPress / Webflow, paste the same text from [PRIVACY.md](PRIVACY.md) and [TERMS.md](TERMS.md).

Then open both URLs on a phone (Safari, not logged into a CMS preview) and confirm:

- It says **iOS**, Screen Time, no accounts, local storage
- Last updated **13 September 2026** or later
- Contact `privacy@iqralock.app` is an inbox you read

The app links those exact URLs on the paywall and You → About.

---

## 3. Paid Apps Agreement, banking, tax — BLOCKER for real subscriptions

App Store Connect → Agreements, Tax, and Banking:

1. Accept the **Paid Applications Agreement**.
2. Complete **banking** (account for proceeds).
3. Complete **tax** forms (W-9 / W-8 as applicable).

Until this is Active, `Product.products(for:)` returns an empty list and the production paywall shows “Subscriptions aren't available”.

---

## 4. Create the subscription products — BLOCKER

App Store Connect → your app → Subscriptions.

1. Create a **subscription group**, name it `IqraLock Pro`.
2. Add two auto-renewable subscriptions:

| Product ID (must match code) | Type | Suggested price | Introductory offer |
|---|---|---|---|
| `com.tahaarif.iqralock.pro.annual` | 1 year | USD 29.99 | 3-day free trial |
| `com.tahaarif.iqralock.pro.weekly` | 1 week | USD 2.99 | none |

3. Localization: English (U.S.) display name + description for each.
4. Set **localized prices** for the storefronts you sell in (or use Apple’s equalizations).
5. Review screenshot: one paywall screenshot per subscription (or the group). Apple requires this the first time.

The first version of the **app** and the **first subscriptions** must be submitted **together**. You cannot ship IAP after the app is already approved unless you submit a new app version.

Create a **Sandbox Tester** (Users and Access → Sandbox) to try real StoreKit on TestFlight / Xcode. Sandbox trials expire in minutes.

Code IDs live in `StoreKitPurchaseService.ProductID`. If you change an ID in App Store Connect, change the code to match.

---

## 5. Switch the build to production StoreKit

Already done on `cursor/production-submission-fa08`:

- `PurchaseServiceFactory` returns `StoreKitPurchaseService` when `INTERNAL_TESTFLIGHT` is **not** set
- That branch does **not** set `INTERNAL_TESTFLIGHT` on Release

Do **not** archive `cursor/testflight-internal-fa08` for App Review. That branch mocks purchases.

Upload production TestFlight from `cursor/production-submission-fa08` the same way: Actions → TestFlight → run workflow **from that branch**.

---

## 6. Signing team and build number

- GitHub secret `DEVELOPMENT_TEAM` must be your 10-character Team ID.
- The workflow sets `CURRENT_PROJECT_VERSION` to `github.run_number`. Do not lower it.
- After ~10 CI uploads, revoke leftover **Apple Distribution** certificates (see [CI_TESTFLIGHT_SETUP.md](CI_TESTFLIGHT_SETUP.md)).
- Permanent fix (needs a Mac once): export a `.p12` and add `SIGNING_CERTIFICATE_P12` + `SIGNING_CERTIFICATE_PASSWORD`, then we can wire keychain import into the workflow.

In Xcode on a Mac (optional local archive): set Team on all four targets.

---

## 7. Icon, screenshots, listing

App Store Connect → app listing:

- Final 1024×1024 icon (must match the asset catalog)
- 6.7" and 6.1" iPhone screenshots (required sizes for current iOS)
- Description, keywords, support URL, marketing URL
- Category (Lifestyle or Education — pick one and keep it)
- Age rating questionnaire
- Review notes: explain Family Controls self-restriction; include a sandbox tester if asked

---

## 8. Privacy Nutrition Labels vs the binary

`IqraLock/PrivacyInfo.xcprivacy` currently declares:

- **No** tracking
- **No** collected analytics types (the app uses `NoopAnalytics`)
- UserDefaults access (`CA92.1`)
- File timestamp access (`C617.1`) for bundled resources

In App Store Connect → App Privacy, answer the same:

- Data not collected from the user by IqraLock
- Purchases are processed by Apple (you typically still disclose Purchase History / Financial Info **if** you use StoreKit entitlements — when you turn on production StoreKit, add Purchase History back to the manifest and to the Nutrition Label: linked to the user, not used for tracking, purpose App Functionality)

If you later enable PostHog, update **both** the manifest and the Nutrition Label **before** that build ships. Do not leave Product Interaction declared while analytics are a no-op.

---

## 9. Paywall / App Review copy (already in code)

On both branches:

- Renewal line follows the **selected** plan (weekly vs yearly + trial)
- Visible **Privacy Policy** and **Terms of Use** links
- The **10% sadaqah** claim is **removed**. Apple Guideline 3.1.1 / 5.1.1 will reject an unverifiable charity cut.

If you later run a real sadaqah program:

1. Document the recipient, percentage, and payout path
2. Do not imply Apple or the IAP price is a charitable donation unless you use Apple’s approved charity flows
3. Put the claim back only after legal/compliance review

---

## 10. Final physical-device regression (production build)

Install the **production** TestFlight (StoreKit, no internal menu):

1. Cold launch
2. Tab switching
3. Prayer log persists after kill
4. Bookmark vs khatm cursor
5. Lock-screen ayah + short unlock + automatic re-lock
6. Denied notification permission (app still usable)
7. **Sandbox purchase** yearly (trial) and weekly
8. **Restore purchases** on a second install / after Reset is gone
9. Family PIN session lock
10. Shield attention notification → You → Focus

---

## 11. What I (the agent) still cannot do

| Task | Why |
|---|---|
| Click **Actions → TestFlight → Run** | GitHub token cannot dispatch that workflow |
| Accept Paid Apps Agreement / tax / banking | Your Apple ID |
| Create IAP products | Your App Store Connect |
| Request Family Controls distribution | Your developer account |
| Publish iqralock.app | Your DNS / host |
| Export a signing `.p12` | Needs Keychain on a Mac |
| Answer App Review questions live | You |

After you finish §1–4, say so and we can re-check the production branch (product IDs, manifest, listing copy) before you submit for review.
