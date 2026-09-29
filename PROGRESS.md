# Progress — session handoff

**Last session: 2026-09-28 → 29.** Read this first when resuming; the action
checklist lives in [NEXT_STEPS.md](NEXT_STEPS.md).

---

## Where things stand in one paragraph

An audit found the app **did not work**: `firestore.rules` denied every core
operation, including prediction writes, so the product's whole reason for
existing was non-functional. That is now fixed and covered by 43 rules tests.
Eleven commits sit on the branch `harden/phase-0-secrets`, none pushed — both
pushes were blocked by a permission classifier and are yours to run. Nothing has
been verified on a real device or a real Firebase project; everything is
emulator- and test-verified only.

## Repo state

| | |
|---|---|
| Branch | `harden/phase-0-secrets` (11 commits ahead of local `main`) |
| Local `main` | `17eff25` — history rewritten |
| Remote `main` | `f37552e` — **still pre-rewrite; not yet force-pushed** |
| Working tree | clean |
| Pre-rewrite backup | tag `backup/pre-rewrite-original`, plus `refs/original/refs/heads/*` |

History was rewritten locally: the four `fix: resolve all remaining production
issues` messages now describe what actually changed, and two founding commits
authored by `mahibere.ahaw@example.com` are reattributed. Content is
byte-identical to pre-rewrite — verified with `git diff`.

## Verification status

All green locally, and a fresh clone passes all of it (previously impossible —
CI could never have gone green, because `lib/firebase_options.dart` is gitignored
and `flutter analyze` couldn't resolve it):

```bash
flutter analyze --fatal-infos          # clean, under a strict ruleset
flutter test                           # 44 passed
dart format --set-exit-if-changed lib test
cd functions && npm test               # 9 passed
cd functions && npm run test:rules     # 43 passed
```

**Never verified:** anything on a device, against a deployed project. See
NEXT_STEPS.md §3.

---

## What the audit found

### The app could not work as committed

`firestore.rules` denied all six core operations. The defining example:
`prediction_model.dart` emitted `pointsEarned`, while the rules omitted it from
the `hasOnly` allowlist *and* simultaneously required it to equal `0` —
mutually unsatisfiable, so **no prediction could ever be written**. Editing
predictions, the global leaderboard, league standings, joining by invite code
and badge awards were all denied too. Nothing had ever exercised the rules; the
most recent commit was titled "fix: resolve all remaining production issues".

### Live exposure

The football-data.org key was recoverable from the **public** repo's history.
**Still needs rotating** — see NEXT_STEPS.md §1.

### Monetization worked in neither direction

`setPremium` granted premium to any authenticated caller with one `curl` — no
receipt, no expiry. Ads earned £0 because the ad unit id is an AdMob *App* ID
(the `~` gives it away), and the missing manifest entries crashed Android at
launch. The paywall sold "Cloud Sync", which every user already got free.

### Engineering weaknesses

No dependency injection anywhere; 21 tests that only covered pure functions
(two contradicting their own group name, two asserting a constant equals
itself); `analysis_options.yaml` untouched since `flutter create`; 190+ hex
literals with a `ThemeData` that was defined and ignored; four duplicate avatar
widgets; six copy-pasted nav cards; scoring that threw past ~250 players;
no crash reporting at all.

---

## What was done — 11 commits

| Commit | What |
|---|---|
| `693ab05` | Key into Secret Manager; add the missing `functions` block to `firebase.json` (the documented deploy command could not work); close a `.gitignore` gap that left 142 MB of `node_modules` one `git add -A` from being committed |
| `e5c2fc0` | **Fix all six rule denials + 43 rules tests.** Added a `publicProfiles` projection so leaderboards read across users without opening `/users`; moved the kickoff lock to a server-clock comparison; validated scorelines; locked down `users/create` |
| `faae08d` | Scoring: chunk the batch (it exceeded 500 ops past ~250 players and threw), commit fixture status **last** so retries are safe, validate inputs; add transactional `joinLeague`; move badges server-side; dirty-check `updateFixtureStatus` (~7,900 wasted writes/day); `enforceAppCheck` on all callables |
| `b0ab458` | Client: read `publicProfiles`; `update` instead of `set` on edit; fix the cold-start hang that bricked the app offline; fix two launch crashes (missing AdMob manifest entries) |
| `90113e6` | `dart format` + commit the untracked `.github/` and `functions/test/` |
| `5db968b` | `lib/theme/` tokens; `UserAvatar` replaces four copies; `NavCard` + a table replaces six (home screen 631→389); split the test file; delete dead code |
| `8356166` | First widget tests and first service tests (`fake_cloud_firestore`); strict lints surfacing 357 issues, all fixed |
| `198d134` | README rewrite; CI fixed; LICENSE |
| `61741d2` | Hoist four in-`build()` futures/streams; add Crashlytics + `runZonedGuarded` |
| `7dcc3b0` | Split the god-screens (833→146, 686→211); dedupe the score stepper |
| `090611f` | NEXT_STEPS.md |

### Bugs found by the work itself, not the audit

- A widget test caught a real accessibility bug in `NavCard` — it announced as
  two nodes instead of one button.
- `discarded_futures` caught purchase statuses being dropped: pending payments
  vanished silently and `completePurchase` was fire-and-forget, so the store
  replayed purchases every launch.
- `_isPremium = true` ran even when `setPremium` threw — cancelling offline
  granted premium free.
- Two `_rankColor` copies disagreed: one painted rank 4+ bronze, the other muted.
- The missed-prediction penalty guard read a `createdAt` the client never wrote,
  so it could never work.

---

## Decisions locked with you (don't relitigate)

- **Portfolio first, revenue later.** Target role: **mobile / Flutter engineer.**
- **Free-to-play + subscription/ads only. No cash prizes, ever** — a cash pot
  meets the UK Gambling Act 2005 definition and needs a Gambling Commission
  licence (lebom.app, a Premier League predictor, was suspended over exactly
  this).
- **App Check enforced at the boundary, not per rule** — console enforcement for
  Firestore runs before rules, and callables declare `enforceAppCheck`. Repeating
  `request.app != null` in every rule made the ruleset untestable, which is how
  the bugs survived.
- **Joining a league is a callable**, not a client write.
- **Store release is out of scope** for now.
- **Commit messages carry no `Co-Authored-By` trailer.**

---

## Environment gotchas

- **Rules tests need Java** (the Firestore emulator is a Java process):
  ```bash
  export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
  ```
  `openjdk` was installed via brew last session; it is keg-only, so it is not on
  `PATH` by default.
- **The emulator runs on port 8089, not 8080** — 8080 is occupied by YACReader on
  this machine. Set in both `firebase.json` and `functions/test/rules.test.js`.
- `lib/firebase_options.dart` is gitignored; `lib/firebase_options.dart.template`
  exists so CI can analyze a clean clone.

---

## What's left, in priority order

Full detail and commands in [NEXT_STEPS.md](NEXT_STEPS.md).

1. **Rotate the API key.** Still exposed in public history.
2. **Push** — force-push rewritten `main`, push the branch, open the PR. Blocked
   for me; commands are in NEXT_STEPS.md §2.
3. **Deploy and verify end to end on a device.** This is the plan's Phase 1 exit
   criterion and the one thing no test can substitute for. Checklist in
   NEXT_STEPS.md §3.
4. **Six screenshots.** The highest-value remaining task — this is a mobile app
   whose README shows none of it. Spec in `screenshots/README.md`.
5. **Before any paid release:** receipt-verify `setPremium`, add expiry and a
   RTDN/ASSN webhook, fix or remove the ad unit id, add account deletion, add a
   privacy policy, replace the debug signing key. Tracked in the README's
   "Project status" section.

### Not done from the approved plan

- `predict_screen.dart` is still 564 lines — the largest remaining file, and the
  only screen not decomposed. It is good code (the live countdown is the best
  work in the repo), so this is tidying, not repair.
- No analytics, so there's no funnel data to inform the paywall.
- The 1-hour lock window is still duplicated in three client files; the
  authoritative check is server-side now, so these are display-only, but a shared
  constant would be better.
