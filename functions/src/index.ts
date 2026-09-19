import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as https from 'https';

admin.initializeApp();
const db = admin.firestore();

const API_KEY = process.env.FOOTBALL_DATA_API_KEY;
const API_BASE = 'https://api.football-data.org/v4';
const COMPETITION = 'PL';

// ── HTTP request helper ────────────────────────────────────────────────────────

function apiRequest(path: string): Promise<any> {
  const options = {
    hostname: 'api.football-data.org',
    path: `/v4/${path}`,
    method: 'GET',
    headers: {
      'X-Auth-Token': API_KEY,
      'Content-Type': 'application/json',
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode !== 200) {
          reject(new Error(`API error ${res.statusCode}: ${data}`));
          return;
        }
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

// ── Fixture model ──────────────────────────────────────────────────────────────

interface ApiFixture {
  fixtureId: string;
  homeTeam: string;
  awayTeam: string;
  kickoff: admin.firestore.Timestamp;
  homeScore: number | null;
  awayScore: number | null;
  status: string; // upcoming | live | finished
  competition: string;
}

function mapApiStatus(raw: string): string {
  switch (raw) {
    case 'FINISHED':
    case 'AWARDED':
      return 'finished';
    case 'IN_PLAY':
    case 'PAUSED':
    case 'HALFTIME':
      return 'live';
    default:
      return 'upcoming';
  }
}

function parseFixture(raw: any): ApiFixture {
  const homeTeamData = raw.homeTeam;
  const awayTeamData = raw.awayTeam;
  const score = raw.score?.fullTime || {};
  return {
    fixtureId: raw.id.toString(),
    homeTeam: homeTeamData.shortName || homeTeamData.name,
    awayTeam: awayTeamData.shortName || awayTeamData.name,
    kickoff: admin.firestore.Timestamp.fromDate(
      new Date(raw.utcDate)
    ),
    homeScore: score.home ?? null,
    awayScore: score.away ?? null,
    status: mapApiStatus(raw.status),
    competition: 'Premier League',
  };
}

// ── Callable: syncFixtures ──────────────────────────────────────────────────────

export const syncFixtures = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  // Verify admin via admin_roles collection
  const adminDoc = await db
    .collection('admin_roles')
    .doc(context.auth.uid)
    .get();
  if (!adminDoc.exists || !adminDoc.data()?.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Admin access required'
    );
  }

  if (!API_KEY) {
    throw new functions.https.HttpsError(
      'internal',
      'API key not configured'
    );
  }

  try {
    // Fetch upcoming fixtures
    const upcoming = await apiRequest(
      `competitions/${COMPETITION}/matches?status=SCHEDULED,TIMED&limit=50`
    );

    const batch = db.batch();
    const upcomingFixtures: ApiFixture[] = [];

    for (const raw of upcoming.matches || []) {
      const fixture = parseFixture(raw);
      const docRef = db.collection('fixtures').doc(fixture.fixtureId);
      batch.set(docRef, fixture, { merge: true });
      if (fixture.status === 'upcoming') upcomingFixtures.push(fixture);
    }

    // Fetch live + finished fixtures
    const liveFinished = await apiRequest(
      `competitions/${COMPETITION}/matches?status=FINISHED,IN_PLAY,PAUSED,HALFTIME&limit=100`
    );

    let updatedLiveFinished = 0;
    for (const raw of liveFinished.matches || []) {
      const fixture = parseFixture(raw);
      const docRef = db.collection('fixtures').doc(fixture.fixtureId);
      // Use set+merge instead of update to handle non-existent docs
      batch.set(docRef, {
        fixtureId: fixture.fixtureId,
        homeTeam: fixture.homeTeam,
        awayTeam: fixture.awayTeam,
        kickoff: fixture.kickoff,
        competition: fixture.competition,
        status: fixture.status,
        homeScore: fixture.homeScore,
        awayScore: fixture.awayScore,
      }, { merge: true });
      updatedLiveFinished++;
    }

    await batch.commit();

    return {
      upcoming: upcomingFixtures.length,
      liveAndFinished: updatedLiveFinished,
    };
  } catch (error: any) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ── Callable: checkAdmin ────────────────────────────────────────────────────────

export const checkAdmin = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Sign in required'
      );
    }

    // Check admin_roles collection (managed server-side only)
    const adminDoc = await db
      .collection('admin_roles')
      .doc(context.auth.uid)
      .get();

    return { isAdmin: adminDoc.exists && adminDoc.data()?.isAdmin === true };
  }
);

// ── Callable: setPremium ────────────────────────────────────────────────────────
// Server-side write for isPremium (prevents client spoofing).
// Only ever sets isPremium: true — revocation must happen server-side.

export const setPremium = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Sign in required'
      );
    }

    // Use context.auth.uid — never trust client-supplied userId
    const userId = context.auth.uid;

    await db.collection('users').doc(userId).set(
      { isPremium: true },
      { merge: true }
    );

    return { success: true };
  }
);

// ── Callable: scoreFixtureResults ─────────────────────────────────────────────

export const scoreFixtureResults = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Sign in required'
      );
    }

    // Verify admin via admin_roles collection
    const adminDoc = await db
      .collection('admin_roles')
      .doc(context.auth.uid)
      .get();
    if (!adminDoc.exists || !adminDoc.data()?.isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Admin access required'
      );
    }

    const fixtureId: string = data.fixtureId;
    const homeScore: number = data.homeScore;
    const awayScore: number = data.awayScore;
    const currentUserId: string = data.currentUserId || '';

    // Idempotency guard: skip if fixture is already scored
    const fixtureSnap = await db.collection('fixtures').doc(fixtureId).get();
    if (!fixtureSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Fixture not found'
      );
    }

    // Idempotency guard: skip if fixture is already scored
    const fixtureData = fixtureSnap.data();
    if (fixtureData && fixtureData.status === 'finished') {
      return {
        skipped: true,
        message: 'Fixture already scored',
        pointsEarned: null,
      };
    }

    // Update fixture with final score
    const batch = db.batch();
    batch.update(fixtureSnap.reference, {
      homeScore,
      awayScore,
      status: 'finished',
    });

    // Score all predictions for this fixture
    const predSnap = await db
      .collection('predictions')
      .where('fixtureId', '==', fixtureId)
      .get();

    const predictedUids = new Set<string>();
    let currentUserPoints: number | null = null;

    for (const doc of predSnap.docs) {
      const pred = doc.data();
      const userId: string = pred.userId;
      predictedUids.add(userId);

      const homeGuess = pred.homeGuess as number;
      const awayGuess = pred.awayGuess as number;
      const points = calculatePoints(
        homeGuess,
        awayGuess,
        homeScore,
        awayScore
      );

      batch.update(doc.reference, {
        pointsEarned: points,
        locked: true,
      });

      batch.update(db.collection('users').doc(userId), {
        totalPoints: admin.firestore.FieldValue.increment(points),
        weeklyPoints: admin.firestore.FieldValue.increment(points),
      });

      if (userId === currentUserId) {
        currentUserPoints = points;
      }
    }

    // -1 for users who didn't predict (chunked to respect 500-write batch limit)
    const usersSnap = await db.collection('users').get();
    for (let i = 0; i < usersSnap.docs.length; i += 500) {
      const batch2 = db.batch();
      const end = Math.min(i + 500, usersSnap.docs.length);
      for (let j = i; j < end; j++) {
        const userDoc = usersSnap.docs[j];
        if (!predictedUids.has(userDoc.id)) {
          batch2.update(userDoc.reference, {
            totalPoints: admin.firestore.FieldValue.increment(-1),
            weeklyPoints: admin.firestore.FieldValue.increment(-1),
          });
        }
      }
      await batch2.commit();
    }

    await batch.commit();

    return { pointsEarned: currentUserPoints };
  }
);

// ── Pure scoring logic (mirrors client-side ScoringService) ───────────────────

function calculatePoints(
  homeGuess: number,
  awayGuess: number,
  homeScore: number,
  awayScore: number
): number {
  if (homeGuess === homeScore && awayGuess === awayScore) return 5;
  const guessOutcome = outcome(homeGuess, awayGuess);
  const actualOutcome = outcome(homeScore, awayScore);
  if (guessOutcome === actualOutcome) {
    if (homeGuess - awayGuess === homeScore - awayScore) return 3;
    return 1;
  }
  return 0;
}

function outcome(home: number, away: number): string {
  if (home > away) return 'home';
  if (away > home) return 'away';
  return 'draw';
}

// ── Scheduled: updateFixtureStatus ────────────────────────────────────────────
// Runs every 10 minutes to update live/finished fixture statuses.
// Requires Blaze plan for scheduled functions.

export const updateFixtureStatus = functions.pubsub
  .schedule('every 10 minutes from 09:00 to 22:00')
  .timeZone('Europe/London')
  .onRun(async (context) => {
    if (!API_KEY) {
      console.warn('API key not configured, skipping sync');
      return null;
    }

    try {
      const liveFinished = await apiRequest(
        `competitions/${COMPETITION}/matches?status=FINISHED,IN_PLAY,PAUSED,HALFTIME&limit=100`
      );

      const batch = db.batch();
      let updated = 0;

      for (const raw of liveFinished.matches || []) {
        const fixture = parseFixture(raw);
        const docRef = db.collection('fixtures').doc(fixture.fixtureId);
        batch.update(docRef, {
          status: fixture.status,
          homeScore: fixture.homeScore,
          awayScore: fixture.awayScore,
        });
        updated++;
      }

      if (updated > 0) {
        await batch.commit();
      }

      // Recalculate user stats for all affected users
      // (handled by client-side listener on fixtures stream)

      console.log(`Updated ${updated} fixture statuses`);
    } catch (error: any) {
      console.error('Fixture status update failed:', error);
    }

    return null;
  });

// ── Scheduled: resetWeeklyPoints ──────────────────────────────────────────────
// Runs every Monday at 07:00 to reset weekly points.

export const resetWeeklyPoints = functions.pubsub
  .schedule('0 7 * * 1')
  .timeZone('Europe/London')
  .onRun(async (context) => {
    const snap = await db.collection('users').get();

    let count = 0;
    for (let i = 0; i < snap.docs.length; i += 500) {
      const batch = db.batch();
      const end = Math.min(i + 500, snap.docs.length);
      for (let j = i; j < end; j++) {
        batch.update(snap.docs[j].reference, { weeklyPoints: 0 });
        count++;
      }
      await batch.commit();
    }

    console.log(`Reset weekly points for ${count} users`);
    return null;
  });
