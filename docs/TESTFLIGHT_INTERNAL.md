# Internal TestFlight tonight

This is the **debug / internal** upload. It is a Release archive with `INTERNAL_TESTFLIGHT` compiled in:

- Mock purchases (tap Yearly or Weekly → Pro unlocks, **no charge**)
- **You → Internal TestFlight → Reset to first run**
- Test shield-attention notification
- 2-minute re-lock scheduler
- Home banner so you never confuse it with production

Branch: `cursor/testflight-internal-fa08`

The production flavor is a different branch: `cursor/production-submission-fa08` (real StoreKit, no reset menu). Do not mix them up.

The cloud agent **cannot** start the upload. GitHub Actions returns 403 for `workflow_dispatch` from this environment. You run it in the browser.

## You do this (about 15–25 minutes)

1. Confirm GitHub secrets exist (repo → Settings → Secrets → Actions):
   - `APP_STORE_CONNECT_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_PRIVATE_KEY`
   - `DEVELOPMENT_TEAM`
   If any are missing, follow [CI_TESTFLIGHT_SETUP.md](CI_TESTFLIGHT_SETUP.md) first.

2. Confirm **Family Controls (distribution)** is approved on all four App IDs. Without that, archive signing fails. See [PRODUCTION_SUBMISSION.md](PRODUCTION_SUBMISSION.md) § Family Controls.

3. Open [Actions → TestFlight](https://github.com/tahaarif3/quran-scroll-mobile/actions/workflows/testflight.yml).

4. **Run workflow**
   - Use workflow from: **`cursor/testflight-internal-fa08`**
   - Notify testers: leave off
   - Run

5. Wait for the green job, then 5–15 minutes of Apple processing.

6. On your iPhone: TestFlight → IqraLock → install this build.

7. Walk [the device script](#device-script) below.

If the workflow fails on certificates (“maximum number of certificates”), revoke old **Apple Distribution** certs at developer.apple.com as described in CI_TESTFLIGHT_SETUP.md.

## Device script

- Cold launch
- Tabs: Today / Read / Progress / You
- Log a prayer → Progress shows 1 of 5 and streak bubble fills
- Bookmark an ayah behind your khatm → leave Read → reopen → still that ayah
- Shield a real app → confirm it is blocked
- Read one ayah → 5/10/30 min unlock → wait or use **Schedule 2-minute re-lock**
- Deny notifications, then allow later
- Paywall: pick Weekly → footer says **weekly** price; pick Yearly → trial/year text
- Privacy Policy and Terms links open (pages must be live on iqralock.app — see production doc)
- **Reset to first run** and walk onboarding once more
- If Home says the shield needs attention, tap it → You → Focus

## Do not

- Do not submit this branch for App Store review
- Do not give this build to paying customers
- Do not expect real StoreKit sandbox charges
