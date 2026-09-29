# Next steps

Generated 2026-09-29. Delete this file once you've worked through it.

## 1. Rotate the football-data.org API key — do this first

The old key `67ea0c0c…30db` is recoverable from this repo's public git history
(`git log --all -S'<key>' -p`). Rotating is what actually protects you; the
history rewrite below is cosmetic by comparison.

1. Get a new key: https://www.football-data.org/client/register
2. Store it: `firebase functions:secrets:set FOOTBALL_DATA_API_KEY`
3. Revoke the old one in your football-data.org account.

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

## 3. Deploy, then verify end to end

Nothing below has run against a real device or project — I could only verify it
against the emulator and the test suites.

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
