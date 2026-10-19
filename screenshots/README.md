# Screenshots

Drop six PNGs here and link them from the root README:

| File | Screen | What it should show |
|---|---|---|
| `home.png` | Home | Stats grid and navigation cards |
| `predict.png` | Predict | Score entry with the live countdown to lock |
| `results.png` | Results | A finished match with points earned |
| `leaderboard.png` | Leaderboard | Populated top ten with podium colours |
| `league.png` | My League | Standings and a weekly head-to-head |
| `profile.png` | Profile | Badges and stats |

Capture at a consistent device size (iPhone 15 Pro or Pixel 8) and keep them
under ~300 KB each:

```bash
flutter run --release
# then, per screen:
xcrun simctl io booted screenshot screenshots/home.png     # iOS
adb exec-out screencap -p > screenshots/home.png           # Android
```
