# Prediction League

A Flutter + Firebase mobile app for Premier League score prediction. Predict scorelines, earn points on accuracy, and compete on global leaderboards or in private leagues with friends.

[![CI](https://github.com/Mattathiasa/prediction_league/actions/workflows/test.yml/badge.svg)](https://github.com/Mattathiasa/prediction_league/actions/workflows/test.yml)

---

## Screenshots

> **TODO:** add six screenshots to `screenshots/` and link them here, plus a short
> screen recording at the top. For a mobile app this is the most important part of
> the README — see "Contributing to this README" at the bottom.

---

## Why I built this

I wanted a project where the *interesting* problems were not in the UI. A score
predictor looks trivial until you take its integrity seriously:

- **A prediction must be provably submitted before kickoff.** That cannot be
  enforced on the client, and it cannot be enforced by a flag an admin flips
  later. It has to be a server-clock comparison in the security rules.
- **A leaderboard needs to read across users, but user documents are private.**
  Resolving that without making `/users` world-readable is a data-modelling
  decision, not a rules tweak.
- **Scoring a fixture touches every player at once.** Firestore caps a batch at
  500 writes, so "score all predictions" stops working at a few hundred users
  unless you design for it.

Most of the engineering in this repo is about those three problems.

## Scoring

| Accuracy | Points |
|---|---|
| Exact scoreline | 5 |
| Correct result and goal difference | 3 |
| Correct result only | 1 |
| Wrong result | 0 |
| No prediction submitted | −1 |

Scoring runs server-side in `scoreFixtureResults`. The client has a copy of the
same function for display only; the server's result is authoritative.

## Features

- **Google Sign-In**
- **Predictions** with a live countdown, locking one hour before kickoff
- **Leaderboards** — all-time and weekly, paginated
- **Private leagues** — 20 members, 6-character invite code, weekly head-to-head
  pairings (top seed vs bottom seed, middle seed gets the bye)
- **Badges** — first prediction, exact scoreline, five scoring predictions in a row
- **Match reminders** — local notification one hour before kickoff
- **Admin panel** — enter results and trigger scoring; access is verified
  server-side against an `admin_roles` collection that no client can write

---

## Architecture

| Layer | Choice |
|---|---|
| Framework | Flutter (stable) |
| State | `provider` — `ChangeNotifier` + `ChangeNotifierProxyProvider` |
| Backend | Firebase Auth, Firestore, Cloud Functions (TypeScript), App Check |
| Fixture data | [football-data.org](https://www.football-data.org) v4 |
| Notifications | `flutter_local_notifications` (device-local; there is no push) |
| Monetization | `google_mobile_ads`, `in_app_purchase` |

```
lib/
├── models/       Firestore document shapes
├── services/     Firebase access; constructor-injected so they can be faked
├── providers/    ChangeNotifiers bridging services to widgets
├── screens/      One per route
├── widgets/      Shared components
└── theme/        Colour tokens and ThemeData
functions/src/    Cloud Functions
functions/test/   Unit tests and Firestore rules tests
```

### Decisions worth explaining

**`/publicProfiles` mirrors the public half of `/users`.**
`/users` is readable only by its owner. But the leaderboard queries across all
users, and league standings fetch twenty of them at once — and Firestore rejects
a collection query outright if *any* matching document is disallowed, rather than
filtering it. The alternatives were to open `/users` up, or to project the four
public fields into a separate collection that Cloud Functions alone can write.
The projection keeps private stats private and costs one trigger.

**The prediction lock is a rules-level clock comparison.**
```
get(/databases/$(database)/documents/fixtures/$(fixtureId)).data.kickoff
  > request.time + duration.value(1, 'h')
```
`FixtureModel.isLocked` exists for the UI countdown, but it is not a security
boundary — a modified client or a raw REST write ignores it entirely. The rule
costs one document read per prediction write, which is the right trade for the
one property the game cannot function without.

**Joining a league is a callable, not a client write.**
Finding a league by invite code means reading a league you are not yet a member
of. Allowing that from the client would make every league world-readable. The
callable also applies the 20-member cap inside a transaction — a non-transactional
check lets two simultaneous joins both pass at 19/20.

**Admin state is UX only.**
`admin_roles` is unwritable by every client, and each privileged callable
re-reads it rather than trusting the caller. Hiding the admin menu item is
cosmetic; the boundary is server-side and enforced per call.

**App Check is enforced at the boundary, not per rule.**
Console enforcement for Firestore runs before rules evaluate, and the callables
each declare `enforceAppCheck`. Repeating `request.app != null` in every rule
would be redundant *and* would make the ruleset untestable, since the standard
test harness cannot mint App Check tokens.

---

## Testing

```bash
flutter test                      # 44 widget, model and service tests
cd functions && npm test          # scoring logic
cd functions && npm run test:rules  # Firestore rules, against the emulator
```

The rules suite is the one worth looking at. Services take their Firebase
dependencies through the constructor, so `fake_cloud_firestore` covers the
service layer without a live project.

Rules tests need Java for the Firestore emulator:

```bash
brew install openjdk
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
```

---

## Setup

### 1. Prerequisites

Flutter (stable), Node 20, the Firebase CLI, and a Firebase project on the Blaze
plan — scheduled functions require it.

### 2. Install

```bash
flutter pub get
npm --prefix functions ci
```

### 3. Configure Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart`, which is gitignored. A placeholder
lives at `lib/firebase_options.dart.template` so CI can analyze a clean clone.

### 4. Set the football-data.org API key

Get a free key at [football-data.org](https://www.football-data.org/client/register),
then store it in Secret Manager:

```bash
firebase functions:secrets:set FOOTBALL_DATA_API_KEY
```

`syncFixtures` and `updateFixtureStatus` declare it via `runWith({ secrets })`.
It is never sent to the client. For the local emulator, copy
`functions/.env.example` to `functions/.env`.

### 5. Grant yourself admin

In the Firestore console, create `admin_roles/{your_uid}` with `{ isAdmin: true }`.
No client can write this collection.

### 6. Enable App Check

Firebase console → App Check → Firestore → Enforce, and register your debug
token (printed at startup) under the Debug providers.

### 7. Deploy

```bash
firebase deploy --only firestore:rules,functions
```

### 8. Run

```bash
flutter run
```

---

## Project status

Working and tested: predictions, leaderboards, private leagues, scoring, badges,
admin tooling.

Known gaps, tracked honestly rather than hidden:

- **In-app purchases are not receipt-verified.** `setPremium` currently trusts
  any authenticated caller, and entitlements never expire. Do not ship a paid
  build until this is fixed.
- **The banner ad unit id is wrong** — it is an AdMob *App* ID where a unit ID
  belongs, so no ad will ever fill.
- **No account deletion**, which both stores require for apps with sign-in.
- **No privacy policy or terms.**
- **Android release builds are signed with the debug key.**
- **No analytics**, so there is no funnel data to inform the paywall.

The app is not store-ready. Those items are what stands between here and a
submission.

---

## Licence

MIT — see [LICENSE](LICENSE).

---

## Contributing to this README

If you are picking this up: the single highest-value change is adding
screenshots. This is a mobile app whose entire value is visual, and the README
currently shows none of it. Six images and a fifteen-second recording would do
more than any refactor listed above.
