# IqraLock — Privacy Policy

**Last updated: 12 August 2026**

IqraLock is an iOS app that helps you build a daily Qur'an reading habit by shielding distracting
apps until you finish today's pages.

**IqraLock has no accounts, no login, and no servers of our own.** Everything you do in the app
stays on your device.

---

## What stays on your device

All of it. IqraLock stores the following locally, in the app's own storage and in a private App
Group shared with its Screen Time extensions:

- Your onboarding answers — age range, gender, relationship with faith, Arabic reading ability,
  current reading frequency, preferred reading style, and your goals
- Your display name, if you enter one
- Reading progress: pages read, daily records, streaks, bookmarks and your last position
- Your daily page goal and reading preferences
- Which apps you chose to shield, and whether the shield is currently on
- Emergency passes remaining

None of this is transmitted to us. We cannot see it. Deleting IqraLock removes all of it from
your device.

## Screen Time and the apps you shield

IqraLock uses Apple's **Family Controls / Screen Time** framework to shield apps you select.

When you choose apps, Apple's own picker returns **opaque tokens** — not names, not bundle
identifiers. By Apple's design, IqraLock cannot tell which apps you picked, only how many. Those
tokens are stored on your device and are meaningless outside it.

IqraLock does **not** monitor which apps you open, does not record how long you spend in them,
and does not use the Accessibility API. It asks the system to shield a set of tokens, and the
system does the rest.

Granting Screen Time access is required for app blocking. You can revoke it at any time in
iOS Settings, and you can change or clear your app selection in **You → Locked apps**.

## The Qur'an text

The Qur'an is bundled inside the app. Reading it requires no network connection and generates no
requests. Nothing about what you read leaves your device.

- Arabic: Uthmani script (Tanzil), sourced via the quran.com API at build time
- Translation: Saheeh International

## Notifications

IqraLock schedules **local** notifications for reading reminders and unlock confirmations. These
are generated on your device. There is no push server and no notification token is sent anywhere.

## Purchases

Subscriptions are processed by **Apple**. IqraLock never sees or receives your payment details,
card number, or billing address. Apple provides the app with a receipt indicating whether a
subscription is active — nothing more.

Apple's handling of that transaction is governed by
[Apple's Privacy Policy](https://www.apple.com/legal/privacy/).

## Analytics

IqraLock currently collects **no analytics**. The app ships with analytics disabled.

If anonymous product analytics are enabled in a future version, they will cover in-app events
only — such as which onboarding step was viewed — will not be linked to your identity, will never
include the contents of your reading, your app selection, or your answers, and this policy will
be updated before that ships.

## What we never do

- We do not sell your data. There is nothing to sell.
- We do not share your data with advertisers or data brokers.
- We do not track you across apps or websites. The app requests no tracking permission.
- We do not create a profile of you on any server.

## Children

IqraLock is not directed at children under 13. The app asks for an age *range* to personalise
reading projections; this is stored on your device and never transmitted.

## Your control

- **Change your shielded apps:** You → Locked apps
- **Change reading preferences:** You → Reading
- **Revoke Screen Time access:** iOS Settings → Screen Time
- **Delete everything:** delete the app. All local data, including your App Group data, goes with
  it. We hold nothing to delete on our side.

## Changes

If this policy changes, the date at the top changes with it. Material changes will be noted in
the app's release notes.

## Contact

Questions about this policy: **privacy@iqralock.app**
