import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as https from 'https';

admin.initializeApp();
const db = admin.firestore();

// Bound to the functions that need it via `runWith({ secrets: [...] })` below.
// Read lazily rather than at module load, so the value is resolved after Secret
// Manager has injected it into the runtime environment.
const FOOTBALL_DATA_API_KEY = 'FOOTBALL_DATA_API_KEY';
const apiKey = (): string | undefined => process.env[FOOTBALL_DATA_API_KEY];

const COMPETITION = 'PL';

// ── HTTP request helper ────────────────────────────────────────────────────────

function apiRequest(path: string): Promise<any> {
  const options = {
    hostname: 'api.football-data.org',
    path: `/v4/${path}`,
    method: 'GET',
    headers: {
      'X-Auth-Token': apiKey(),
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

export const syncFixtures = functions
  .runWith({ secrets: [FOOTBALL_DATA_API_KEY] })
  .https.onCall(async (data, context) => {
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

    if (!apiKey()) {
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

export const checkAdmin = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
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
  });

// ── Callable: joinLeague ────────────────────────────────────────────────────────
// Joining runs here rather than as a client write for two reasons: looking a
// league up by invite code would otherwise require making every league
// world-readable, and the member cap has to be checked and applied in the same
// transaction or two simultaneous joins can both pass a 19/20 check.

const MAX_LEAGUE_MEMBERS = 20;

export const joinLeague = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Sign in required'
      );
    }

    const raw = typeof data?.inviteCode === 'string' ? data.inviteCode : '';
    const inviteCode = raw.trim().toUpperCase();
    if (!/^[A-Z0-9]{6}$/.test(inviteCode)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invite codes are 6 letters or digits'
      );
    }

    const userId = context.auth.uid;

    const matches = await db
      .collection('leagues')
      .where('inviteCode', '==', inviteCode)
      .limit(1)
      .get();

    if (matches.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'No league found with that code'
      );
    }

    const leagueRef = matches.docs[0].ref;

    const leagueId = await db.runTransaction(async (tx) => {
      const snap = await tx.get(leagueRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError('not-found', 'League no longer exists');
      }

      const memberIds: string[] = snap.data()?.memberIds ?? [];
      if (memberIds.includes(userId)) return snap.id;

      if (memberIds.length >= MAX_LEAGUE_MEMBERS) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          `This league is full (${MAX_LEAGUE_MEMBERS} members)`
        );
      }

      tx.update(leagueRef, {
        memberIds: admin.firestore.FieldValue.arrayUnion(userId),
      });
      return snap.id;
    });

    return { leagueId };
  });

// ── Trigger: keep /publicProfiles in step with /users ───────────────────────────
// /users is private, but the leaderboard and league standings need to read name,
// avatar and points across users. This mirrors just that public subset so those
// queries never require opening up /users itself.

export const syncPublicProfile = functions.firestore
  .document('users/{userId}')
  .onWrite(async (change, context) => {
    const { userId } = context.params;
    const profileRef = db.collection('publicProfiles').doc(userId);

    if (!change.after.exists) {
      await profileRef.delete();
      return;
    }

    const user = change.after.data()!;
    const before = change.before.data();

    // Only the projected fields matter — skip writes that can't change it.
    const projection = {
      displayName: user.displayName ?? '',
      photoUrl: user.photoUrl ?? '',
      totalPoints: user.totalPoints ?? 0,
      weeklyPoints: user.weeklyPoints ?? 0,
      badgeIds: user.badgeIds ?? [],
      isPremium: user.isPremium === true,
    };

    if (
      before &&
      before.displayName === projection.displayName &&
      before.photoUrl === projection.photoUrl &&
      before.totalPoints === projection.totalPoints &&
      before.weeklyPoints === projection.weeklyPoints &&
      before.isPremium === projection.isPremium &&
      JSON.stringify(before.badgeIds ?? []) ===
        JSON.stringify(projection.badgeIds)
    ) {
      return;
    }

    await profileRef.set(projection, { merge: true });
  });

// ── Callable: setPremium ────────────────────────────────────────────────────────
// Server-side write for isPremium (prevents client spoofing).
// Only ever sets isPremium: true — revocation must happen server-side.

export const setPremium = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
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

const BADGE_FIRST_KICK = 'first_kick';
const BADGE_ON_FIRE = 'on_fire';
const BADGE_SNIPER = 'sniper';
const ON_FIRE_STREAK = 5;

// Firestore caps a WriteBatch at 500 operations. Scoring writes two documents
// per prediction (the prediction and its author), so a fixture with more than
// ~249 predictions used to blow the limit and throw — the function was capped
// at roughly 250 players.
const BATCH_LIMIT = 500;

/**
 * Applies writes in batches that respect Firestore's 500-op limit.
 * Ops are applied in order, so callers can rely on earlier chunks landing first.
 */
async function commitInChunks(
  ops: Array<(batch: admin.firestore.WriteBatch) => void>
): Promise<void> {
  for (let i = 0; i < ops.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const op of ops.slice(i, i + BATCH_LIMIT)) op(batch);
    await batch.commit();
  }
}

/** Throws unless `value` is an integer goal tally a real match could produce. */
function requireScore(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0 || value > 20) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${field} must be an integer between 0 and 20`
    );
  }
  return value;
}

/**
 * Recomputes the badges a user has earned from their full scored history.
 * Derived rather than incremented so a re-run cannot double-award.
 */
function earnedBadges(
  predictions: admin.firestore.QueryDocumentSnapshot[]
): string[] {
  if (predictions.length === 0) return [];

  const ordered = [...predictions].sort(
    (a, b) =>
      (a.data().submittedAt?.toMillis() ?? 0) -
      (b.data().submittedAt?.toMillis() ?? 0)
  );

  const badges = [BADGE_FIRST_KICK];

  if (ordered.some((p) => (p.data().pointsEarned ?? 0) === 5)) {
    badges.push(BADGE_SNIPER);
  }

  let streak = 0;
  for (const p of ordered) {
    streak = (p.data().pointsEarned ?? 0) > 0 ? streak + 1 : 0;
    if (streak >= ON_FIRE_STREAK) {
      badges.push(BADGE_ON_FIRE);
      break;
    }
  }

  return badges;
}

export const scoreFixtureResults = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Sign in required'
      );
    }

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

    // Validate before touching anything. `as number` is erased at runtime, so
    // the previous version happily fed NaN or a string into FieldValue.increment
    // and corrupted totalPoints with no way back.
    if (typeof data?.fixtureId !== 'string' || data.fixtureId.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'fixtureId is required'
      );
    }
    const fixtureId: string = data.fixtureId;
    const homeScore = requireScore(data.homeScore, 'homeScore');
    const awayScore = requireScore(data.awayScore, 'awayScore');

    const fixtureSnap = await db.collection('fixtures').doc(fixtureId).get();
    if (!fixtureSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Fixture not found');
    }

    const fixtureData = fixtureSnap.data()!;
    if (fixtureData.status === 'finished') {
      return {
        skipped: true,
        message: 'Fixture already scored',
        pointsEarned: null,
      };
    }

    const predSnap = await db
      .collection('predictions')
      .where('fixtureId', '==', fixtureId)
      .get();

    const predictedUids = new Set<string>();
    const pointsByUser = new Map<string, number>();

    for (const doc of predSnap.docs) {
      const pred = doc.data();
      const userId: string = pred.userId;
      predictedUids.add(userId);
      pointsByUser.set(
        userId,
        calculatePoints(pred.homeGuess, pred.awayGuess, homeScore, awayScore)
      );
    }

    // ── 1. Score the predictions and credit their authors ────────────────────
    const scoringOps: Array<(b: admin.firestore.WriteBatch) => void> = [];

    for (const doc of predSnap.docs) {
      const points = pointsByUser.get(doc.data().userId)!;
      scoringOps.push((b) =>
        b.update(doc.ref, { pointsEarned: points, locked: true })
      );
    }

    // /publicProfiles is not written here — the syncPublicProfile trigger
    // mirrors these increments. Writing both would double-count.
    for (const [userId, points] of pointsByUser) {
      scoringOps.push((b) =>
        b.update(db.collection('users').doc(userId), {
          totalPoints: admin.firestore.FieldValue.increment(points),
          weeklyPoints: admin.firestore.FieldValue.increment(points),
        })
      );
    }

    await commitInChunks(scoringOps);

    // ── 2. Penalise users who were signed up at kickoff but didn't predict ───
    const usersSnap = await db.collection('users').get();
    const kickoff: Date = fixtureData.kickoff.toDate();
    const penaltyOps: Array<(b: admin.firestore.WriteBatch) => void> = [];

    for (const userDoc of usersSnap.docs) {
      if (predictedUids.has(userDoc.id)) continue;

      // Users created after kickoff can't be penalised for missing it.
      const createdAt = userDoc.data().createdAt?.toDate();
      if (createdAt && createdAt.getTime() >= kickoff.getTime()) continue;

      penaltyOps.push((b) =>
        b.update(userDoc.ref, {
          totalPoints: admin.firestore.FieldValue.increment(-1),
          weeklyPoints: admin.firestore.FieldValue.increment(-1),
        })
      );
    }

    await commitInChunks(penaltyOps);

    // ── 3. Award badges ──────────────────────────────────────────────────────
    // Derived from each author's full scored history rather than incremented,
    // so re-running this function cannot double-award. Previously this ran on
    // the client, where the rules denied the write every time.
    await Promise.all(
      [...predictedUids].map(async (userId) => {
        const history = await db
          .collection('predictions')
          .where('userId', '==', userId)
          .where('locked', '==', true)
          .get();
        const badges = earnedBadges(history.docs);
        if (badges.length === 0) return;
        await db
          .collection('users')
          .doc(userId)
          .update({
            badgeIds: admin.firestore.FieldValue.arrayUnion(...badges),
          });
      })
    );

    // ── 4. Mark the fixture finished, last ───────────────────────────────────
    // This is what the idempotency guard above reads. Committing it last means
    // a failure anywhere earlier leaves the fixture unscored and the whole
    // operation safely repeatable — the previous ordering committed penalties
    // first, so a retry after a failure docked non-predictors twice.
    await fixtureSnap.ref.update({
      homeScore,
      awayScore,
      status: 'finished',
    });

    return { pointsEarned: pointsByUser.get(context.auth.uid) ?? null };
  });

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

// Exported for testing
export { calculatePoints, outcome };

// ── Scheduled: updateFixtureStatus ────────────────────────────────────────────
// Runs every 10 minutes to update live/finished fixture statuses.
// Requires Blaze plan for scheduled functions.

export const updateFixtureStatus = functions
  .runWith({ secrets: [FOOTBALL_DATA_API_KEY] })
  .pubsub.schedule('every 10 minutes from 09:00 to 22:00')
  .timeZone('Europe/London')
  .onRun(async (context) => {
    if (!apiKey()) {
      console.warn('API key not configured, skipping sync');
      return null;
    }

    try {
      const liveFinished = await apiRequest(
        `competitions/${COMPETITION}/matches?status=FINISHED,IN_PLAY,PAUSED,HALFTIME&limit=100`
      );

      const incoming = (liveFinished.matches || []).map(parseFixture);
      if (incoming.length === 0) {
        console.log('No live or finished fixtures to update');
        return null;
      }

      // Read current state first and write only what actually changed. This runs
      // 79 times a day; blind set+merge rewrote up to 100 documents every run,
      // and each rewrite fans out to every connected client's fixture listener.
      const existing = await db.getAll(
        ...incoming.map((f: ApiFixture) =>
          db.collection('fixtures').doc(f.fixtureId)
        )
      );
      const current = new Map(
        existing.map((snap) => [snap.id, snap.exists ? snap.data() : undefined])
      );

      const batch = db.batch();
      let updated = 0;

      for (const fixture of incoming) {
        const prev = current.get(fixture.fixtureId);
        const unchanged =
          prev &&
          prev.status === fixture.status &&
          prev.homeScore === fixture.homeScore &&
          prev.awayScore === fixture.awayScore;
        if (unchanged) continue;

        // set+merge handles docs that don't exist yet (e.g. first run before syncFixtures)
        batch.set(
          db.collection('fixtures').doc(fixture.fixtureId),
          {
            fixtureId: fixture.fixtureId,
            homeTeam: fixture.homeTeam,
            awayTeam: fixture.awayTeam,
            kickoff: fixture.kickoff,
            competition: fixture.competition,
            status: fixture.status,
            homeScore: fixture.homeScore,
            awayScore: fixture.awayScore,
          },
          { merge: true }
        );
        updated++;
      }

      if (updated > 0) {
        await batch.commit();
      }

      console.log(
        `Checked ${incoming.length} fixtures, wrote ${updated} changed`
      );
    } catch (error: any) {
      console.error('Fixture status update failed:', error);
    }

    return null;
  });

// ── Scheduled: resetWeeklyPoints ──────────────────────────────────────────────
// Runs every Monday at 07:00 to reset weekly points.

async function resetAllWeeklyPoints(): Promise<number> {
  const snap = await db.collection('users').get();
  const stale = snap.docs.filter((d) => (d.data().weeklyPoints ?? 0) !== 0);

  await commitInChunks(
    stale.map((d) => (b: admin.firestore.WriteBatch) =>
      b.update(d.ref, { weeklyPoints: 0 })
    )
  );

  console.log(`Reset weekly points for ${stale.length} users`);
  return stale.length;
}

export const resetWeeklyPoints = functions.pubsub
  .schedule('0 7 * * 1')
  .timeZone('Europe/London')
  .onRun(async () => {
    await resetAllWeeklyPoints();
    return null;
  });

// Manual escape hatch for the admin screen. Shares the scheduled job's
// implementation rather than reimplementing it on the client, where the rules
// (correctly) deny a client writing another user's points, and where an
// unbounded `users` scan would run on a phone.
export const resetWeeklyPointsNow = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Sign in required'
      );
    }

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

    const count = await resetAllWeeklyPoints();
    return { count };
  });
