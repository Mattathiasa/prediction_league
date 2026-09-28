/**
 * Firestore security rules tests.
 *
 * Run with:  npm run test:rules      (starts the emulator for you)
 *
 * These exist because every core feature of the app was silently denied by the
 * rules — predictions could not be created or edited, the leaderboard and league
 * standings were rejected, and leagues could not be joined. Nothing exercised the
 * rules, so nothing caught it. Each `describe` below corresponds to one of those
 * breakages; they are the regression net for that class of bug.
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  query,
  orderBy,
  limit,
  where,
  getDocs,
  documentId,
  Timestamp,
  arrayUnion,
} = require('firebase/firestore');

const ALICE = 'alice_uid';
const BOB = 'bob_uid';

// Kickoff far enough out that the 1-hour prediction window is open.
const OPEN_KICKOFF = () => Timestamp.fromMillis(Date.now() + 6 * 60 * 60 * 1000);
// Kickoff 10 minutes away — inside the 1-hour lock window.
const LOCKED_KICKOFF = () => Timestamp.fromMillis(Date.now() + 10 * 60 * 1000);

let testEnv;

/** A prediction document exactly as the Flutter client writes it. */
function predictionDoc(overrides = {}) {
  return {
    predictionId: 'alice_fx1',
    userId: ALICE,
    fixtureId: 'fx1',
    homeGuess: 2,
    awayGuess: 1,
    pointsEarned: 0,
    submittedAt: Timestamp.now(),
    locked: false,
    ...overrides,
  };
}

/** A signup document exactly as UserModel.toMap() emits it. */
function userDoc(uid, overrides = {}) {
  return {
    uid,
    displayName: 'Alice',
    photoUrl: '',
    totalPoints: 0,
    weeklyPoints: 0,
    streak: 0,
    bestStreak: 0,
    accuracy: 0,
    badgeIds: [],
    highestWeeklyPoints: 0,
    predictionsCount: 0,
    correctResults: 0,
    exactScoreCount: 0,
    isPremium: false,
    ...overrides,
  };
}

async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

// ── Minimal test harness (matches the style of scoring.test.js) ───────────────

const suites = [];
let currentSuite = null;

function describe(name, fn) {
  currentSuite = { name, tests: [] };
  suites.push(currentSuite);
  fn();
  currentSuite = null;
}

function it(name, fn) {
  currentSuite.tests.push({ name, fn });
}

async function run() {
  testEnv = await initializeTestEnvironment({
    projectId: 'prediction-league-rules-test',
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '../../firestore.rules'),
        'utf8'
      ),
      host: '127.0.0.1',
      port: 8089,
    },
  });

  let passed = 0;
  let failed = 0;

  for (const suite of suites) {
    console.log(`\n${suite.name}`);
    for (const t of suite.tests) {
      await testEnv.clearFirestore();
      try {
        await t.fn();
        console.log(`  ✓ ${t.name}`);
        passed++;
      } catch (err) {
        console.log(`  ✗ ${t.name}`);
        console.log(`      ${err.message.split('\n')[0]}`);
        failed++;
      }
    }
  }

  await testEnv.cleanup();
  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
}

// ── Users ─────────────────────────────────────────────────────────────────────

describe('users', () => {
  it('lets a user create their own doc with zeroed stats', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(setDoc(doc(db, 'users', ALICE), userDoc(ALICE)));
  });

  it('rejects a signup that self-assigns premium', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'users', ALICE), userDoc(ALICE, { isPremium: true }))
    );
  });

  it('rejects a signup that self-assigns points', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'users', ALICE), userDoc(ALICE, { totalPoints: 999999 }))
    );
  });

  it('rejects a signup that self-assigns badges', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'users', ALICE), userDoc(ALICE, { badgeIds: ['sniper'] }))
    );
  });

  it('rejects a signup with an unknown field', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'users', ALICE), userDoc(ALICE, { isAdmin: true }))
    );
  });

  it('rejects creating a doc for another user', async () => {
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(setDoc(doc(db, 'users', ALICE), userDoc(ALICE)));
  });

  it('allows a user to edit their own display name', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), userDoc(ALICE)));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users', ALICE), { displayName: 'Alice B' })
    );
  });

  it('rejects a user granting themselves premium later', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), userDoc(ALICE)));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(updateDoc(doc(db, 'users', ALICE), { isPremium: true }));
  });

  it('rejects a user writing their own points later', async () => {
    await seed((db) =>
      setDoc(doc(db, 'users', ALICE), { uid: ALICE, totalPoints: 0 })
    );
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(db, 'users', ALICE), { totalPoints: 500 })
    );
  });

  it('rejects reading another user private doc', async () => {
    await seed((db) => setDoc(doc(db, 'users', BOB), { uid: BOB }));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(getDoc(doc(db, 'users', BOB)));
  });
});

// ── Public profiles (leaderboard projection) ──────────────────────────────────

describe('publicProfiles', () => {
  it('allows the leaderboard query across all users', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'publicProfiles', ALICE), {
        displayName: 'Alice',
        totalPoints: 30,
        weeklyPoints: 5,
      });
      await setDoc(doc(db, 'publicProfiles', BOB), {
        displayName: 'Bob',
        totalPoints: 10,
        weeklyPoints: 2,
      });
    });
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'publicProfiles'),
          orderBy('totalPoints', 'desc'),
          limit(20)
        )
      )
    );
  });

  it('allows a whereIn fetch of league member profiles', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'publicProfiles', ALICE), { totalPoints: 1 });
      await setDoc(doc(db, 'publicProfiles', BOB), { totalPoints: 2 });
    });
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'publicProfiles'),
          where(documentId(), 'in', [ALICE, BOB])
        )
      )
    );
  });

  it('is not writable by clients', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'publicProfiles', ALICE), { totalPoints: 999 })
    );
  });

  it('is not readable when signed out', async () => {
    await seed((db) => setDoc(doc(db, 'publicProfiles', ALICE), { totalPoints: 1 }));
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'publicProfiles', ALICE)));
  });
});

// ── Predictions ───────────────────────────────────────────────────────────────

describe('predictions', () => {
  it('allows creating a prediction before the lock window', async () => {
    await seed((db) =>
      setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: OPEN_KICKOFF(),
        status: 'upcoming',
      })
    );
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc())
    );
  });

  it('rejects a prediction inside the 1-hour lock window', async () => {
    await seed((db) =>
      setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: LOCKED_KICKOFF(),
        status: 'upcoming',
      })
    );
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc())
    );
  });

  it('rejects a prediction that pre-awards itself points', async () => {
    await seed((db) =>
      setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: OPEN_KICKOFF(),
        status: 'upcoming',
      })
    );
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(
        doc(db, 'predictions', 'alice_fx1'),
        predictionDoc({ pointsEarned: 5 })
      )
    );
  });

  it('rejects a prediction created as already locked', async () => {
    await seed((db) =>
      setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: OPEN_KICKOFF(),
        status: 'upcoming',
      })
    );
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc({ locked: true }))
    );
  });

  it('rejects predicting on behalf of another user', async () => {
    await seed((db) =>
      setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: OPEN_KICKOFF(),
        status: 'upcoming',
      })
    );
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc())
    );
  });

  it('rejects a non-integer scoreline', async () => {
    await seed((db) =>
      setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: OPEN_KICKOFF(),
        status: 'upcoming',
      })
    );
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(
        doc(db, 'predictions', 'alice_fx1'),
        predictionDoc({ homeGuess: 'abc' })
      )
    );
  });

  it('rejects an out-of-range scoreline', async () => {
    await seed((db) =>
      setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: OPEN_KICKOFF(),
        status: 'upcoming',
      })
    );
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(
        doc(db, 'predictions', 'alice_fx1'),
        predictionDoc({ homeGuess: 1000 })
      )
    );
  });

  it('allows editing a prediction before the lock window', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: OPEN_KICKOFF(),
        status: 'upcoming',
      });
      await setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc());
    });
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'predictions', 'alice_fx1'), {
        homeGuess: 3,
        awayGuess: 0,
        submittedAt: Timestamp.now(),
      })
    );
  });

  it('rejects editing a prediction after kickoff passes', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: LOCKED_KICKOFF(),
        status: 'upcoming',
      });
      await setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc());
    });
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(db, 'predictions', 'alice_fx1'), { homeGuess: 3 })
    );
  });

  it('rejects editing a locked prediction', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: OPEN_KICKOFF(),
        status: 'upcoming',
      });
      await setDoc(
        doc(db, 'predictions', 'alice_fx1'),
        predictionDoc({ locked: true })
      );
    });
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(db, 'predictions', 'alice_fx1'), { homeGuess: 3 })
    );
  });

  it('rejects an edit that awards itself points', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        kickoff: OPEN_KICKOFF(),
        status: 'upcoming',
      });
      await setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc());
    });
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(db, 'predictions', 'alice_fx1'), { pointsEarned: 5 })
    );
  });

  it('rejects reading another user prediction', async () => {
    await seed((db) =>
      setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc())
    );
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(getDoc(doc(db, 'predictions', 'alice_fx1')));
  });
});

// ── Leagues ───────────────────────────────────────────────────────────────────

describe('leagues', () => {
  const league = (overrides = {}) => ({
    name: 'The Office',
    adminId: ALICE,
    memberIds: [ALICE],
    inviteCode: 'ABC123',
    createdAt: Timestamp.now(),
    ...overrides,
  });

  it('allows a user to create a league they admin', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(setDoc(doc(db, 'leagues', 'lg1'), league()));
  });

  it('rejects creating a league admined by someone else', async () => {
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(setDoc(doc(db, 'leagues', 'lg1'), league()));
  });

  it('hides leagues you are not a member of', async () => {
    await seed((db) => setDoc(doc(db, 'leagues', 'lg1'), league()));
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(getDoc(doc(db, 'leagues', 'lg1')));
  });

  it('rejects enumerating leagues by invite code', async () => {
    // Joining goes through the joinLeague callable precisely so that this
    // query does not have to be allowed — permitting it would make every
    // league in the database world-readable.
    await seed((db) => setDoc(doc(db, 'leagues', 'lg1'), league()));
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      getDocs(
        query(collection(db, 'leagues'), where('inviteCode', '==', 'ABC123'))
      )
    );
  });

  it('rejects a client-side self-join', async () => {
    await seed((db) => setDoc(doc(db, 'leagues', 'lg1'), league()));
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      updateDoc(doc(db, 'leagues', 'lg1'), { memberIds: arrayUnion(BOB) })
    );
  });

  it('rejects a member adding somebody else', async () => {
    await seed((db) =>
      setDoc(doc(db, 'leagues', 'lg1'), league({ memberIds: [ALICE, BOB] }))
    );
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      updateDoc(doc(db, 'leagues', 'lg1'), {
        memberIds: [ALICE, BOB, 'carol_uid'],
      })
    );
  });

  it('rejects a member evicting another member', async () => {
    await seed((db) =>
      setDoc(doc(db, 'leagues', 'lg1'), league({ memberIds: [ALICE, BOB] }))
    );
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      updateDoc(doc(db, 'leagues', 'lg1'), { memberIds: [BOB] })
    );
  });

  it('rejects creating a league pre-populated with other members', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'leagues', 'lg1'), league({ memberIds: [ALICE, BOB] }))
    );
  });

  it('rejects a non-admin seizing adminId', async () => {
    await seed((db) =>
      setDoc(doc(db, 'leagues', 'lg1'), league({ memberIds: [ALICE, BOB] }))
    );
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(updateDoc(doc(db, 'leagues', 'lg1'), { adminId: BOB }));
  });

  it('allows a member to leave', async () => {
    await seed((db) =>
      setDoc(doc(db, 'leagues', 'lg1'), league({ memberIds: [ALICE, BOB] }))
    );
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'leagues', 'lg1'), { memberIds: [ALICE] })
    );
  });

  it('allows the admin to rename the league', async () => {
    await seed((db) => setDoc(doc(db, 'leagues', 'lg1'), league()));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'leagues', 'lg1'), { name: 'Renamed' })
    );
  });

  it('rejects a non-admin renaming the league', async () => {
    await seed((db) =>
      setDoc(doc(db, 'leagues', 'lg1'), league({ memberIds: [ALICE, BOB] }))
    );
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(updateDoc(doc(db, 'leagues', 'lg1'), { name: 'Hijacked' }));
  });

  it('rejects a non-admin deleting the league', async () => {
    await seed((db) =>
      setDoc(doc(db, 'leagues', 'lg1'), league({ memberIds: [ALICE, BOB] }))
    );
    const db = testEnv.authenticatedContext(BOB).firestore();
    const { deleteDoc } = require('firebase/firestore');
    await assertFails(deleteDoc(doc(db, 'leagues', 'lg1')));
  });
});

// ── Fixtures & admin roles ────────────────────────────────────────────────────

describe('fixtures and admin_roles', () => {
  it('lets any signed-in user read fixtures', async () => {
    await seed((db) =>
      setDoc(doc(db, 'fixtures', 'fx1'), { fixtureId: 'fx1', status: 'upcoming' })
    );
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(getDoc(doc(db, 'fixtures', 'fx1')));
  });

  it('rejects a client writing a fixture', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'fixtures', 'fx1'), { fixtureId: 'fx1', homeScore: 9 })
    );
  });

  it('rejects a client granting itself admin', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'admin_roles', ALICE), { isAdmin: true })
    );
  });

  it('rejects signed-out fixture reads', async () => {
    await seed((db) => setDoc(doc(db, 'fixtures', 'fx1'), { fixtureId: 'fx1' }));
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'fixtures', 'fx1')));
  });
});

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
