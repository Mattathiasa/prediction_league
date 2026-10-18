# Next steps

Generated 2026-09-29. Delete this file once you've worked through it.

## 1. Revoke the exposed football-data.org API key — do this first

The old key `67ea0c0c…30db` is recoverable from this repo's public git history
(`git log --all -S'<key>' -p`). Revoking it is what actually protects you; the
history rewrite below is cosmetic by comparison.

Decided 2026-10-18: this project stays on the Spark plan and is never
deployed live (see README's "Project status" — Cloud Functions require Blaze
for any deployment, not just the scheduled jobs, and that's not worth a
billing method for a portfolio piece). So there's no new key to provision or
store in Secret Manager — just revoke the old one in your football-data.org
account settings. If you ever do deploy this live, get a fresh key then and
follow the README's step 4 under Setup.

## 2. Push (I could not — force-push and branch-push are blocked for me)

History was rewritten locally: the four `fix: resolve all remaining production
issues` messages now describe what actually changed, and two founding commits
authored by `mahibere.ahaw@example.com` are reattributed to you. Content is
byte-identical — verified with `git diff` against the pre-rewrite tree.

```bash
# Rewritten main. --force-with-lease refuses if the remote moved since I checked.
git push --force-with-lease=main:f37552e09779b69153a2023e2c9b6fc374ce5cfb origin main

# The ten new commits
git push -u origin harden/phase-0-secrets

# PR
gh pr create --base main --head harden/phase-0-secrets \
  --title "Make the app work: repair Firestore rules, scoring, and the client" \
  --body "See the individual commit messages; each explains the defect it fixes."
```

If anything looks wrong, the pre-rewrite history is at
`backup/pre-rewrite-original` and `refs/original/refs/heads/*`.

## 3. Deploy and verify end to end — skipped, by decision

This step is **intentionally not happening.** Deploying Cloud Functions
requires the Blaze plan (a billing method), which isn't worth it for a
portfolio piece with no real users. Everything is verified against the
emulator and the test suites instead — see README's "Project status".

If you ever reconsider and want a live, device-verified instance:

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```

Then, on a device, walk the full loop and confirm each step:

- [ ] Sign in with Google
- [ ] Submit a prediction, then **edit** it (this never worked before)
- [ ] Confirm it appears on the leaderboard
- [ ] Create a league; join it from a second account using the invite code
- [ ] Score a fixture as admin; confirm points and badges land
- [ ] Confirm a prediction is **rejected** after kickoff passes
- [ ] Launch in airplane mode: expect the retry screen, not a frozen spinner

App Check will reject your debug build until you register its token: it prints
at startup — add it under Firebase console → App Check → Debug providers.

## 4. Screenshots — the highest-value remaining task

`screenshots/README.md` lists the six shots and the capture commands. This is a
mobile app whose README currently shows none of it; six images do more for a
recruiter skim than any refactor in this branch.

## 5. Before any paid release

Tracked in the README's "Project status" section:

- `setPremium` (`functions/src/index.ts`) trusts any authenticated caller — no
  receipt validation, no expiry. **Do not ship a paid build until this is fixed.**
- The banner ad unit id is an AdMob *App* ID where a unit ID belongs, so no ad
  will ever fill.
- No account deletion (both stores require it for apps with sign-in).
- No privacy policy or terms.
- Android release builds are signed with the debug key
  (`android/app/build.gradle`).
