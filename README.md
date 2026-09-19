# Prediction League

A Flutter mobile app for Premier League football (soccer) score prediction. Users predict match results, earn points based on prediction accuracy, compete on leaderboards, and join private leagues with friends.

Built with Flutter, Firebase (Auth, Firestore, Cloud Messaging), and the [football-data.org](https://www.football-data.org) API.

---

## Features

### For Users

- **Google Sign-In** — One-tap authentication via Google
- **Match Predictions** — Predict the scoreline for upcoming Premier League fixtures
  - Prediction window closes **1 hour before kickoff** (hard lock)
  - Real-time countdown timer on each fixture
- **Scoring System** — Earn points for correct predictions:

  | Accuracy | Points | Label |
  |----------|--------|-------|
  | Exact scoreline | 5 | Exact score! |
  | Correct result + correct goal difference | 3 | Right result + GD |
  | Correct result only | 1 | Right result |
  | Wrong result | 0 | Wrong result |
  | Missed / no prediction | -1 | No prediction |

- **Results Screen** — View finished matches, your predictions, and points earned per fixture
- **Leaderboards** — Global rankings sorted by total points or weekly points (load more / infinite scroll)
- **Private Leagues** — Create or join leagues with a 6-character invite code
  - League-specific standings with "vs you" point differential
  - Admin can reset weekly points (typically done each Monday)
- **Match Reminders** — Local notifications scheduled 1 hour before each kickoff
- **Badges** — Achievement system:
  - **First Kick** — Submit your first prediction
  - **Sniper** — Predict an exact scoreline (5 pts)
  - **On Fire** — 5 consecutive predictions with points > 0
- **Admin Panel** — PIN-protected screen (default PIN: `1234`) for entering final scores and scoring predictions
- **Share Predictions** — Share your prediction for a fixture via the native share sheet

### For Admins

- Enter match results, which triggers automatic scoring for all user predictions
- Score entry triggers a post-result notification showing the current user's points

---

## Screenshots

> *Add screenshots to `screenshots/` and update the image paths below.*
> 
> `<img src="screenshots/auth.png" width="200" />` `<img src="screenshots/home.png" width="200" />` `<img src="screenshots/predict.png" width="200" />` `<img src="screens/league.png" width="200" />`

---

## Architecture

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (stable channel) |
| State Management | `provider` package (ChangeNotifier / ChangeNotifierProxyProvider) |
| Backend | Firebase (Auth, Firestore, Cloud Functions, Cloud Messaging) |
| External API | football-data.org (Premier League fixtures & results) |
| Local Notifications | `flutter_local_notifications` + `timezone` |
| Image Caching | `cached_network_image` |
| Sharing | `share_plus` |
| Monetization | `google_mobile_ads`, `in_app_purchase` |

### App Icon & Splash

Custom app icons and splash screens are configured via `pubspec.yaml` and use assets in `assets/icon/` and `assets/splash/`. Run `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create` to regenerate.

### Project Structure

```
prediction_league/
├── android/                        # Android native config
├── ios/                            # iOS native config (Flutter + Podfile)
├── lib/
│   ├── config/
│   │   └── app_config.dart         # Admin PIN, API config (client-side)
│   ├── models/
│   │   ├── fixture_model.dart      # Fixture data model (API + Firestore)
│   │   ├── league_model.dart       # League data model
│   │   ├── prediction_model.dart   # Prediction data model (with copyWith)
│   │   └── user_model.dart         # User data model (stats, badges, streaks)
│   ├── services/
│   │   ├── auth_service.dart       # Google Sign-In + Firestore user mgmt
│   │   ├── badge_service.dart      # Badge definitions + awarding logic
│   │   ├── fixture_service.dart    # Firestore streams + Cloud Functions sync
│   │   │                                        # (syncFixtures, scoreFixtureResults)
│   │   ├── league_service.dart     # League CRUD, invite codes, member mgmt
│   │   ├── notification_service.dart # Match reminders + result notifications
│   │   ├── prediction_service.dart # Submit predictions (with lock check)
│   │   ├── result_service.dart       # Batch scoring of predictions
│   │   └── scoring_service.dart      # Pure scoring logic (5/3/1/0 points)
│   ├── providers/
│   │   ├── fixture_provider.dart   # Sync fixtures + schedule reminders
│   │   ├── league_provider.dart    # League streams + create/join
│   │   └── prediction_provider.dart # Prediction CRUD + optimistic updates
│   ├── screens/
│   │   ├── admin_screen.dart       # PIN-gated result entry
│   │   ├── auth_screen.dart        # Google Sign-In screen
│   │   ├── create_league_screen.dart
│   │   ├── fixture_list_screen.dart # Upcoming fixtures + sync
│   │   ├── home_screen.dart        # Dashboard (stats, quick nav)
│   │   ├── join_league_screen.dart
│   │   ├── leaderboard_screen.dart # All-time + weekly tabs
│   │   ├── my_league_screen.dart   # League standings + picker
│   │   ├── predict_screen.dart     # Score entry with countdown timer
│   │   ├── profile_screen.dart     # Stats + badges
│   │   └── results_screen.dart     # Finished matches + points summary
│   ├── firebase_options.dart       # Firebase config (generated, not committed)
│   └── main.dart                   # App entry + MultiProvider setup
├── functions/
│   ├── src/
│   │   └── index.ts                # Cloud Functions (syncFixtures, updateFixtureStatus)
│   ├── package.json
│   ├── tsconfig.json
│   └── (node_modules & lib excluded via .gitignore)
├── test/
│   └── widget_test.dart            # Unit tests (ScoringService, models)
├── firestore.rules                 # Security rules
├── firestore.indexes.json          # Composite index definitions
├── firebase.json                   # Firebase project config
└── pubspec.yaml                    # Flutter dependencies + icon/splash config
```

---

## Data Flow

```
User predicts scores
  → Firestore (predictions collection, owner-only, lock-enforced)

Fixture data (football-data.org API, server-side)
  → Cloud Function (syncFixtures, admin-only)
  → Firestore (fixtures collection, server-side writes only)
  → Client streams (upcomingFixtures, finishedFixtures)

Admin enters final score
  → Cloud Function (scoreFixtureResults, admin-only)
  → Firestore batch writes (predictions + users + fixtures)
  → BadgeService.checkAndAwardPostResultBadges()
  → Local notification via NotificationService
```

### Fixture Syncing (Server-Side)

The football-data.org API key is stored in **Cloud Functions environment variables** (never in the client). The `syncFixtures` callable function fetches fixtures server-side, batch-writes to Firestore, and returns a summary count. The client calls this function instead of accessing the API directly.

A scheduled function (`updateFixtureStatus`) runs every 10 minutes during match hours to auto-update fixture statuses and scores.

**Requirements:** Blaze plan for scheduled functions. On Spark Plan, use the admin screen's sync button to trigger `syncFixtures` manually.

### Admin Authentication

Admin access is verified server-side via the `admin_roles` Firestore collection. To grant admin access to a user:

```bash
firebase firestore:indexes  # (apply rules first)
# Then add via Firebase console or a one-time setup script:
firebase functions:call checkAdmin --data '{}'
```

Or add a document to `admin_roles/{uid}` with `{isAdmin: true}` directly in the Firebase console.

---

## Firestore Data Model

### Collections

| Collection | Document Fields |
|---|---|
| **users** (`{uid}`) | `displayName`, `photoUrl`, `totalPoints`, `weeklyPoints`, `streak`, `bestStreak`, `accuracy`, `badgeIds[]`, `predictionsCount`, `correctResults`, `exactScoreCount`, `highestWeeklyPoints`, `isPremium` |
| **fixtures** (`{fixtureId}`) | `homeTeam`, `awayTeam`, `kickoff` (Timestamp), `homeScore`, `awayScore`, `status` (`upcoming`/`live`/`finished`), `competition` |
| **predictions** (`{userId}_{fixtureId}`) | `userId`, `fixtureId`, `homeGuess`, `awayGuess`, `pointsEarned`, `submittedAt`, `locked` |
| **leagues** (`{leagueId}`) | `name`, `adminId`, `memberIds[]` (max 20), `inviteCode`, `createdAt` |
| **admin_roles** (`{uid}`) | `isAdmin: true` (server-managed only) |

### Security Rules

All collections require App Check. Enable enforcement in the Firebase console (App Check → Firestore → Enforce).

```
users/{userId}         → read/write by owner only (isPremium server-managed)
fixtures/{fixtureId}   → read by any authenticated user; create/update/delete denied to clients (Cloud Functions only)
predictions/{predId}   → create by owner (restricted fields); update by owner before lock only; pointsEarned/locked server-managed
leagues/{leagueId}     → read by members; create/manage by admin; updates limited to name, memberIds, inviteCode
admin_roles/{uid}      → read by owner; no client writes
```

---

## Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, >= 3.3.4)
- Node.js 20+ (for Firebase Functions)
- A [football-data.org](https://www.football-data.org/client/register) API key (free tier: 10 calls/min)
- A Firebase project with the following services enabled (Blaze plan recommended)
  - Authentication (Google Sign-In)
  - Firestore
  - Cloud Functions
  - App Check
  - Cloud Messaging (Android)
  - (Optional) AdMob for ads

### 1. Clone and Install

```bash
git clone https://github.com/Mattathiasa/prediction_league.git
cd prediction_league

flutter pub get
```

### 2. Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

### 3. Configure Firebase

The app is pre-configured for Firebase project `predictionleague-25968`. To use your own project:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your project
flutterfire configure
```

This generates `lib/firebase_options.dart` (excluded from version control — see `.gitignore`).

### 4. Set Up the football-data.org API Key

Configure the API key as a Firebase Functions environment variable:

```bash
cd functions
npm install
firebase functions:configure -o '{"footballDataApiKey":"YOUR_API_KEY"}'
```

> **Security:** The API key lives only in Cloud Functions environment variables and is never exposed to the client. The `syncFixtures` callable function uses it server-side.

> **Admin setup:** Add your Firebase UID to the `admin_roles` collection in Firestore:
> ```
> admin_roles/{your_uid} → { isAdmin: true }
> ```

### 5. Enable App Check

In the Firebase console, navigate to App Check → Firestore → Enforce. This prevents non-genuine clients from accessing your data.

### 6. Deploy

```bash
firebase deploy
```

### 6. Run Locally

```bash
# Start the Firebase emulator (Firestore + Functions)
firebase emulators:start --only firestore,functions

# In another terminal, run the Flutter app
flutter run
```

---

## Development

### Running Tests

```bash
flutter test
```

Test coverage includes:
- `ScoringService.calculatePoints()` — all scoring scenarios (5, 3, 1, 0 points)
- `ScoringService.pointsLabel()` — label mapping
- `FixtureModel` — `isLocked`, `isFinished`, `isLive`, `isUpcoming`, `fromApi()`, `fromFirestore()`
- `PredictionModel` — `copyWith()` and Firestore round-trip serialization

### Scoring Logic

The `ScoringService` is a pure, stateless utility — no Firebase dependencies. This makes it trivially testable:

```
Exact score (e.g. 2-1 predicted, 2-1 actual) → 5 pts
Correct result, same goal difference (e.g. 3-1 predicted, 2-0 actual) → 3 pts
Correct result, different goal difference (e.g. 1-0 predicted, 3-1 actual) → 1 pt
Wrong result → 0 pts
```

### Prediction Window

A fixture's prediction window closes **1 hour before kickoff**. The `FixtureModel.isLocked` property checks this on the client. The `PredictScreen` shows a live countdown until lock. Once locked, predictions are read-only.

### Cloud Functions

Located in `functions/src/index.ts`:

| Function | Type | Trigger | Description |
|---|---|---|---|
| `syncFixtures` | Callable (`https.onCall`) | Admin client call | Fetches upcoming PL fixtures from football-data.org (server-side), batch-writes to Firestore |
| `scoreFixtureResults` | Callable (`https.onCall`) | Admin client call | Scores all predictions for a fixture atomically (with idempotency guard) |
| `updateFixtureStatus` | Scheduled (`pubsub.schedule`) | Every 10 min (match hours) | Updates live/finished fixture statuses and scores |
| `resetWeeklyPoints` | Scheduled (`pubsub.schedule`) | Every Monday 07:00 UTC | Resets all users' weeklyPoints to 0 |
| `checkAdmin` | Callable (`https.onCall`) | Any authenticated user | Verifies admin access via `admin_roles` collection |

```bash
cd functions
npm run build     # Compile TypeScript
npm run serve     # Start emulator for Functions
npm run deploy    # Deploy Functions only
```

---

## Configuration Reference

### Admin Authentication

Admin access is verified **server-side** via the `admin_roles` Firestore collection. There is no client-side PIN. To grant admin access:

1. Add your Firebase UID to `admin_roles/{uid}` with `{isAdmin: true}` in the Firebase console
2. The app will call the `checkAdmin` Cloud Function on admin screen open

### Prediction Lock Window

The prediction lock window is hardcoded to 1 hour before kickoff (`FixtureModel.isLocked`).

### Monetization

The app supports AdMob banner ads and premium in-app subscriptions:

**AdMob Ads**
- Banner ads are shown at the bottom of the HomeScreen for non-premium users
- Ad unit ID: `ca-app-pub-3210681117962880~9348060115`
- Replace with your production AdMob ID before publishing
- Initialize Google Mobile Ads in `main.dart` via `MobileAds.instance.initialize()`

**Premium Subscriptions**
- In-app products: `premium_monthly`, `remove_ads`
- Premium state stored in Firestore (`users/{uid}.isPremium`) — server-managed
- Purchase flow handled by `SubscriptionService` (initialized on auth state change)
- PaywallScreen accessible via HomeScreen → menu → "Go Premium"
- Features: Ad-free, premium badge, early access, priority sync

---

## Contributing

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Run `flutter test` to ensure tests pass
5. Submit a PR

---

## License

This project is provided as-is for educational purposes.
