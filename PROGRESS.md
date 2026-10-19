# Progress — session handoff

**Last session: 2026-10-18 → 19.** Read this first when resuming.

---

## Where things stand in one paragraph

Big pivot this session: after the previous session left the app code-only
(tested, never deployed), the user asked what it'd take to make it **live and
working**, like a real fantasy-sports app. They firmly decided to stay on
Firebase's free **Spark** plan rather than upgrade to Blaze — which means
**no Cloud Functions can be deployed at all**, not just the scheduled ones.
Decision, confirmed and not to be relitigated: keep `functions/src/index.ts`
and its test suite exactly as-is (a tested, server-authoritative reference
design and the Blaze upgrade path), and add a **second, parallel
client-driven implementation** of every privileged operation, with
`firestore.rules` rewritten to allow it. That work is done and pushed.
What's left is deploying it for real, which is currently blocked on a
Firebase CLI login mix-up (see below) — fix that first.

## Repo state

| | |
|---|---|
| Branch | `harden/phase-0-secrets`, pushed, matches `origin` exactly |
| `main` | pushed (rewritten history from last session), PR #1 open |
| Working tree | clean |
| Firebase project | `predictionleague-25968` (Spark plan) |

## This session's commits (newest first)

| Commit | What |
|---|---|
| `626d49d` | Replaced every Cloud Functions call with a client-driven write: `checkAdmin`→direct read, `joinLeague`→client transaction, `setPremium`→self-write (grant-only), `syncFixtures`/`updateFixtureStatus`→manual admin "sync now" hitting football-data.org directly, `scoreFixtureResults`→full client port (chunked batches, penalties, badges, same ordering), `resetWeeklyPointsNow`→new `AdminService` + opportunistic once-per-week auto-run, `syncPublicProfile` trigger→every `/users` writer also writes `/publicProfiles` in the same batch. `cloud_functions` removed from `pubspec.yaml`. |
| `b0bc5d2` | Rewrote `firestore.rules` for the client-driven model (bounded, not wide-open — see the file's own header comment) + 72 rules tests (29 new, 43 original behaviors preserved where unchanged). |
| `6aed981` | **Superseded, see warning below.** Documented a "stays code-only, never deployed" decision — made *before* the pivot above. |

### ⚠️ Stale docs — fix in Phase 6 below

`README.md`'s "Project status" section and `NEXT_STEPS.md` §1/§3 still carry
the `6aed981` framing ("intentionally never deployed... not a live service").
That's now wrong — the whole point of this session was reversing that. Don't
trust those sections until Phase 6 rewrites them.

## What was done this session, roughly in order

1. Rotated the leaked football-data.org key by deleting that account
   entirely (no self-service token reset existed; usage was trivial, 2
   requests, free tier). The old key is dead.
2. Pushed the rewritten `main` + `harden/phase-0-secrets`, opened PR #1.
3. User asked what's left for a genuinely live, polished app. Audited the
   repo (see the fork/agent output from that turn if still in context —
   covered app icon/splash, onboarding, push, analytics, account deletion,
   privacy policy, store signing, CI, feature depth, test depth, error
   handling, versioning). Most polish items were already solid; real gaps:
   no onboarding, no push, no analytics, no settings screen, no screenshots,
   store-readiness items (receipt verification, signing, privacy policy —
   out of scope since store submission isn't a goal).
4. Resolved the Spark-vs-Blaze tension (see Decisions below) by choosing to
   go live on Spark via a client-driven rewrite rather than paying for Blaze.
5. Rewrote `firestore.rules` + rules tests (commit `b0bc5d2`).
6. Ported every Cloud Function to a client-driven equivalent (commit
   `626d49d`). All 44 Flutter tests, 72 rules tests, 9 functions tests pass.
7. Attempted to deploy rules to the live project — **blocked**: the Firebase
   CLI was logged in as `shimelesbezawork@gmail.com` (a previous
   collaborator's account, per the user), which lacked permission to enable
   the Firestore API on `predictionleague-25968` (403 on
   `serviceusage.services.use`). Ran `firebase logout` (succeeded), started
   `firebase login`, handed the user the auth URL — **the user paused before
   pasting back the authorization code**. `firebase login:list` still shows
   the old account as of this writing.

---

## What's left, in order

### 1. Finish the Firebase CLI re-login — do this first

```bash
firebase login:list   # currently still shows shimelesbezawork@gmail.com — wrong
firebase login         # run this; it prints a URL and a session code
```
Open the URL, sign in as **mattathiasabraham@gmail.com**, then run
`firebase login <authorizationCode>` with the code the page gives you.
Confirm with `firebase login:list` that it now shows the right account
before doing anything else.

### 2. Deploy rules to the live project

```bash
firebase deploy --only firestore:rules,firestore:indexes --project predictionleague-25968
```

### 3. Get a new football-data.org key

The old account was deleted this session (see above). Register fresh at
https://www.football-data.org/client/register, then wire the key via
`--dart-define=FOOTBALL_DATA_API_KEY=...` when building/running — **do not
commit it**. `lib/services/fixture_service.dart` reads it via
`String.fromEnvironment('FOOTBALL_DATA_API_KEY')`.

### 4. First real sign-in + grant yourself admin

Run the app against the live project (needs step 1 done, and
`lib/firebase_options.dart` present locally — it's gitignored, regenerate
with `flutterfire configure` if missing). Sign in once with Google to create
your `/users` + `/publicProfiles` docs, note your uid, then in the Firebase
console create `admin_roles/{your_uid}` with `{isAdmin: true}`.

### 5. Full device walkthrough

Once admin is granted: sign in, submit + edit a prediction, confirm it hits
the leaderboard, create a league + join it from a second account, use the
admin screen's "Sync fixtures now" then enter a result and confirm scoring
lands (points, badges), confirm a prediction is rejected after kickoff,
try the weekly-reset button, confirm airplane-mode shows the retry screen
rather than hanging.

### 6. Polish items the user asked for (not started)

- Settings screen (`lib/screens/settings_screen.dart` — new): move sign-out
  and "Go Premium" out of `home_screen.dart`'s popup menu; notification
  preferences toggle; About/legal section (placeholders are fine).
- First-run onboarding: short `PageView` intro, gated by a
  `shared_preferences` flag, before `_AuthWrapper` in `main.dart`.
- Firebase Analytics: add `firebase_analytics` to `pubspec.yaml` (Spark-
  compatible, enable in console), wire `FirebaseAnalyticsObserver`, log a
  handful of events (sign-in, prediction submitted, league joined, badge
  earned).
- Local-only "rank changed" notification in `notification_service.dart` —
  compare cached rank/weekly points on each leaderboard/home load, fire a
  local notification when it changes. **Real push (FCM) is explicitly ruled
  out** — would need a client-embedded send credential, which is a genuine
  abuse vector (anyone who decompiles the app could spam every installed
  user). Don't revisit this; local-only is the deliberate substitute.

### 7. Screenshots

Once there's real, populated data (after step 5): capture the six shots
`screenshots/README.md` specifies on an iOS simulator
(`xcrun simctl io booted screenshot`), link them from the root README.

### 8. Docs rewrite

Fix the stale `6aed981` framing (see warning above). `README.md`'s
"Project status" and Architecture sections need a "two implementations of
the privileged operations" explanation (`functions/src/index.ts` = server-
authoritative/Blaze path, not deployed; the Dart services in
`lib/services/` = client-driven, what's actually live). `NEXT_STEPS.md` §1
and §3 need rewriting to match — §1 no longer needs a new key stored via
Secret Manager (there's no Secret Manager on Spark), §3 is no longer
"skipped by decision," it's the real device-walkthrough checklist (see #5
above).

---

## Decisions locked this session (don't relitigate)

- **Stay on Spark, go live anyway** via a client-driven rewrite of every
  privileged operation. Don't suggest Blaze again — asked and declined
  twice.
- **Keep `functions/src/index.ts` as-is** — don't delete it. It's the tested
  server-authoritative reference and the Blaze upgrade path; the README
  should tell this story explicitly once Phase 6 happens.
- **Admin-trusted scoring, accepted.** The admin's own device, authenticated
  as admin, writes points/badges across other users' documents.
  `firestore.rules` bounds the blast radius (plausible point ranges, known
  badge ids, admin-role check) but can't fully re-verify the cross-document
  scoring math the way the old Cloud Function did. Fine for a solo-admin
  demo with no real users or money.
- **No real push notifications.** A true FCM push needs a server trigger
  (Cloud Function); faking it client-side would mean embedding a send
  credential that lets anyone who decompiles the app spam every installed
  user. Local-only "rank changed" notifications are the deliberate
  replacement — see item 6 above.
- **football-data.org key moves client-side**, via `--dart-define`, never
  committed. Accepted because it's a free, read-only, rate-limited key.
  Lost the automatic 10-minute background refresh — replaced by a manual
  admin "sync now" button.
- **Premium is self-granted by the client** (`isPremium` false→true only,
  enforced by rules, never revoked). No server left to verify a receipt or
  expire it — already a documented known gap from last session; it's now
  also how premium gets granted, not just how it fails to expire.
- *(Carried from last session)* Portfolio-first, target role mobile/Flutter
  engineer. Free-to-play only, no cash prizes — UK Gambling Act 2005. Store
  submission out of scope. No `Co-Authored-By` trailer in commit messages.

---

## Environment gotchas (carried over, still true)

- **Rules tests need Java**: `export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"`
- **Firestore emulator runs on port 8089**, not 8080 (set in `firebase.json`
  and `functions/test/rules.test.js`).
- `lib/firebase_options.dart` is gitignored; `lib/firebase_options.dart.template`
  exists so CI can analyze a clean clone — regenerate the real file locally
  with `flutterfire configure` if it's missing when resuming on a new
  machine or after a clone.

## How to resume

Start with item 1 under "What's left, in order" above. If
`/Users/mattathiasa/.claude/plans/abstract-strolling-pie.md` still exists on
this machine, it has the full original phase-by-phase plan this session was
executing — items 1–8 above are that plan's remaining phases (3 through 6),
in order.
