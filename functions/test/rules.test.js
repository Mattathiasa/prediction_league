/**
 * Firestore security rules tests.
 *
 * Run with:  npm run test:rules      (starts the emulator for you)
 *
 * This ruleset targets the Spark/client-driven architecture (see the header
 * comment in firestore.rules): there is no Cloud Function layer deployed, so
 * scoring, league joins, premium grants and fixture sync are all client
 * writes, gated as tightly as a security-rules-only boundary allows. These
 * tests are the regression net for that boundary — both "the intended client
 * operation is allowed" and "everything outside its exact bounds is denied".
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
  deleteDoc,
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
const ADMIN = 'admin_uid';

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

/** A publicProfiles projection exactly as created alongside userDoc(). */
function publicProfileDoc(overrides = {}) {
  return {
    displayName: 'Alice',
    photoUrl: '',
    totalPoints: 0,
    weeklyPoints: 0,
    badgeIds: [],
    isPremium: false,
    ...overrides,
  };
}

async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

async function seedAdmin(uid = ADMIN) {
  await seed((db) => setDoc(doc(db, 'admin_roles', uid), { isAdmin: true }));
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

  it('rejects reading another user private doc', async () => {
    await seed((db) => setDoc(doc(db, 'users', BOB), { uid: BOB }));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(getDoc(doc(db, 'users', BOB)));
  });

  // ── Self premium grant (replaces the setPremium callable) ──────────────────

  it('allows a user to self-grant premium once', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), userDoc(ALICE)));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(updateDoc(doc(db, 'users', ALICE), { isPremium: true }));
  });

  it('rejects a user granting someone else premium', async () => {
    await seed((db) => setDoc(doc(db, 'users', BOB), userDoc(BOB)));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(updateDoc(doc(db, 'users', BOB), { isPremium: true }));
  });

  it('rejects a user revoking their own premium', async () => {
    await seed((db) =>
      setDoc(doc(db, 'users', ALICE), userDoc(ALICE, { isPremium: true }))
    );
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(updateDoc(doc(db, 'users', ALICE), { isPremium: false }));
  });

  it('rejects a premium grant bundled with another field', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), userDoc(ALICE)));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(db, 'users', ALICE), {
        isPremium: true,
        totalPoints: 100,
      })
    );
  });

  // ── Admin scoring writes (replace scoreFixtureResults) ─────────────────────

  it('allows the admin device to credit matching totalPoints/weeklyPoints', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', ALICE), userDoc(ALICE));
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users', ALICE), { totalPoints: 5, weeklyPoints: 5 })
    );
  });

  it('rejects an admin write outside the plausible points range', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', ALICE), userDoc(ALICE));
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'users', ALICE), { totalPoints: 2, weeklyPoints: 2 })
    );
  });

  it('rejects an admin write where totalPoints and weeklyPoints disagree', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', ALICE), userDoc(ALICE));
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'users', ALICE), { totalPoints: 5, weeklyPoints: 3 })
    );
  });

  it('rejects a non-admin performing a scoring-shaped write', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), userDoc(ALICE)));
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      updateDoc(doc(db, 'users', ALICE), { totalPoints: 5, weeklyPoints: 5 })
    );
  });

  it('allows the admin device to award a known badge', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', ALICE), userDoc(ALICE));
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users', ALICE), {
        badgeIds: arrayUnion('first_kick'),
      })
    );
  });

  it('rejects the admin device awarding an unknown badge id', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', ALICE), userDoc(ALICE));
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'users', ALICE), {
        badgeIds: arrayUnion('whatever_i_want'),
      })
    );
  });

  it('rejects the admin device removing an existing badge', async () => {
    await seed(async (db) => {
      await setDoc(
        doc(db, 'users', ALICE),
        userDoc(ALICE, { badgeIds: ['first_kick'] })
      );
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'users', ALICE), { badgeIds: [] })
    );
  });

  it('allows the admin device to reset weeklyPoints to zero', async () => {
    await seed(async (db) => {
      await setDoc(
        doc(db, 'users', ALICE),
        userDoc(ALICE, { weeklyPoints: 12 })
      );
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users', ALICE), { weeklyPoints: 0 })
    );
  });

  it('rejects the admin device resetting weeklyPoints to a non-zero value', async () => {
    await seed(async (db) => {
      await setDoc(
        doc(db, 'users', ALICE),
        userDoc(ALICE, { weeklyPoints: 12 })
      );
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'users', ALICE), { weeklyPoints: 3 })
    );
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

  it('is not readable when signed out', async () => {
    await seed((db) => setDoc(doc(db, 'publicProfiles', ALICE), { totalPoints: 1 }));
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'publicProfiles', ALICE)));
  });

  it('allows a user to create their own zeroed projection', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'publicProfiles', ALICE), publicProfileDoc())
    );
  });

  it('rejects creating a projection pre-loaded with points', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(
        doc(db, 'publicProfiles', ALICE),
        publicProfileDoc({ totalPoints: 999 })
      )
    );
  });

  it('rejects creating a projection for another user', async () => {
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      setDoc(doc(db, 'publicProfiles', ALICE), publicProfileDoc())
    );
  });

  it('allows a user to mirror their own display name edit', async () => {
    await seed((db) => setDoc(doc(db, 'publicProfiles', ALICE), publicProfileDoc()));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'publicProfiles', ALICE), { displayName: 'Alice B' })
    );
  });

  it('allows a user to mirror their own premium grant', async () => {
    await seed((db) => setDoc(doc(db, 'publicProfiles', ALICE), publicProfileDoc()));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'publicProfiles', ALICE), { isPremium: true })
    );
  });

  it('rejects a user writing someone else projection', async () => {
    await seed((db) => setDoc(doc(db, 'publicProfiles', BOB), publicProfileDoc()));
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      updateDoc(doc(db, 'publicProfiles', BOB), { displayName: 'Hijacked' })
    );
  });

  it('allows the admin device to mirror a scoring credit', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'publicProfiles', ALICE), publicProfileDoc());
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'publicProfiles', ALICE), {
        totalPoints: 3,
        weeklyPoints: 3,
      })
    );
  });

  it('rejects a non-admin mirroring a scoring credit', async () => {
    await seed((db) => setDoc(doc(db, 'publicProfiles', ALICE), publicProfileDoc()));
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      updateDoc(doc(db, 'publicProfiles', ALICE), {
        totalPoints: 3,
        weeklyPoints: 3,
      })
    );
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

  // ── Admin scoring (replaces scoreFixtureResults) ────────────────────────────

  it('allows the admin device to lock a prediction at a plausible score', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc());
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'predictions', 'alice_fx1'), {
        pointsEarned: 5,
        locked: true,
      })
    );
  });

  it('rejects the admin device writing an implausible point value', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc());
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'predictions', 'alice_fx1'), {
        pointsEarned: 2,
        locked: true,
      })
    );
  });

  it('rejects the admin device re-locking an already-scored prediction', async () => {
    await seed(async (db) => {
      await setDoc(
        doc(db, 'predictions', 'alice_fx1'),
        predictionDoc({ locked: true, pointsEarned: 5 })
      );
      await seedAdmin();
    });
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertFails(
      updateDoc(doc(db, 'predictions', 'alice_fx1'), {
        pointsEarned: 0,
        locked: true,
      })
    );
  });

  it('rejects a non-admin performing a scoring-shaped update', async () => {
    await seed((db) => setDoc(doc(db, 'predictions', 'alice_fx1'), predictionDoc()));
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      updateDoc(doc(db, 'predictions', 'alice_fx1'), {
        pointsEarned: 5,
        locked: true,
      })
    );
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

  it('allows reading a league you are not a member of', async () => {
    // Read is open to any signed-in user — joining still requires knowing
    // the invite code, which is the actual gate; see firestore.rules.
    await seed((db) => setDoc(doc(db, 'leagues', 'lg1'), league()));
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertSucceeds(getDoc(doc(db, 'leagues', 'lg1')));
  });

  it('allows resolving a league by its invite code', async () => {
    await seed((db) => setDoc(doc(db, 'leagues', 'lg1'), league()));
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertSucceeds(
      getDocs(
        query(collection(db, 'leagues'), where('inviteCode', '==', 'ABC123'))
      )
    );
  });

  it('allows a signed-in user to join by adding only themselves', async () => {
    await seed((db) => setDoc(doc(db, 'leagues', 'lg1'), league()));
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'leagues', 'lg1'), { memberIds: arrayUnion(BOB) })
    );
  });

  it('rejects joining past the 20-member cap', async () => {
    const full = Array.from({ length: 20 }, (_, i) => `member_${i}`);
    await seed((db) =>
      setDoc(doc(db, 'leagues', 'lg1'), league({ memberIds: full }))
    );
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      updateDoc(doc(db, 'leagues', 'lg1'), { memberIds: arrayUnion(BOB) })
    );
  });

  it('rejects a self-join that also smuggles in a second new member', async () => {
    await seed((db) => setDoc(doc(db, 'leagues', 'lg1'), league()));
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      updateDoc(doc(db, 'leagues', 'lg1'), {
        memberIds: [ALICE, BOB, 'carol_uid'],
      })
    );
  });

  it('rejects an already-member "joining" again as a no-op write to other fields', async () => {
    await seed((db) =>
      setDoc(doc(db, 'leagues', 'lg1'), league({ memberIds: [ALICE, BOB] }))
    );
    const db = testEnv.authenticatedContext(BOB).firestore();
    await assertFails(
      updateDoc(doc(db, 'leagues', 'lg1'), { memberIds: [ALICE, BOB] })
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

  it('rejects a non-admin client writing a fixture', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'fixtures', 'fx1'), { fixtureId: 'fx1', homeScore: 9 })
    );
  });

  it('allows the admin device to sync a fixture', async () => {
    await seedAdmin();
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'fixtures', 'fx1'), {
        fixtureId: 'fx1',
        status: 'upcoming',
        homeTeam: 'Arsenal',
        awayTeam: 'Chelsea',
      })
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

// ── Weekly-reset marker ────────────────────────────────────────────────────────

describe('meta/weeklyReset', () => {
  it('allows the admin device to write the reset marker', async () => {
    await seedAdmin();
    const db = testEnv.authenticatedContext(ADMIN).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'meta', 'weeklyReset'), { lastRunWeekStart: '2026-10-12' })
    );
  });

  it('rejects a non-admin writing the reset marker', async () => {
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(
      setDoc(doc(db, 'meta', 'weeklyReset'), { lastRunWeekStart: '2026-10-12' })
    );
  });

  it('rejects a non-admin reading the reset marker', async () => {
    await seed((db) =>
      setDoc(doc(db, 'meta', 'weeklyReset'), { lastRunWeekStart: '2026-10-12' })
    );
    const db = testEnv.authenticatedContext(ALICE).firestore();
    await assertFails(getDoc(doc(db, 'meta', 'weeklyReset')));
  });
});

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
