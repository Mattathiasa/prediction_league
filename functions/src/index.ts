import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';

admin.initializeApp();
const db = admin.firestore();

const FOOTBALL_DATA_API_KEY = '67ea0c0cacb24129947683063d4130db';
const SCHEDULED_MATCHES_URL =
  'https://api.football-data.org/v4/competitions/PL/matches?status=SCHEDULED,TIMED&limit=20';

interface FootballDataMatch {
  id: number;
  utcDate: string;
  status: string;
  homeTeam: { name: string; shortName?: string };
  awayTeam: { name: string; shortName?: string };
  score: {
    fullTime: { home: number | null; away: number | null };
  };
  competition: { name: string };
}

interface FixtureData {
  fixtureId: string;
  homeTeam: string;
  awayTeam: string;
  kickoff: admin.firestore.Timestamp;
  homeScore: number | null;
  awayScore: number | null;
  status: 'upcoming' | 'live' | 'finished';
  competition: string;
}

function mapStatus(rawStatus: string): 'upcoming' | 'live' | 'finished' {
  switch (rawStatus) {
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

function transformMatch(match: FootballDataMatch): FixtureData {
  const status = mapStatus(match.status);
  return {
    fixtureId: match.id.toString(),
    homeTeam: match.homeTeam.shortName ?? match.homeTeam.name,
    awayTeam: match.awayTeam.shortName ?? match.awayTeam.name,
    kickoff: admin.firestore.Timestamp.fromDate(new Date(match.utcDate)),
    homeScore: match.score.fullTime.home,
    awayScore: match.score.fullTime.away,
    status,
    competition: match.competition.name,
  };
}

export const syncFixtures = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to sync fixtures.'
    );
  }

  try {
    const response = await axios.get(SCHEDULED_MATCHES_URL, {
      headers: { 'X-Auth-Token': FOOTBALL_DATA_API_KEY },
      timeout: 10000,
    });

    const matches = response.data.matches as FootballDataMatch[];
    if (!matches || matches.length === 0) {
      return { success: true, count: 0, message: 'No fixtures found' };
    }

    const batch = db.batch();
    let upcomingCount = 0;

    for (const match of matches) {
      const fixture = transformMatch(match);
      const ref = db.collection('fixtures').doc(fixture.fixtureId);
      batch.set(ref, fixture, { merge: true });
      if (fixture.status === 'upcoming') upcomingCount++;
    }

    await batch.commit();

    return {
      success: true,
      count: matches.length,
      upcomingCount,
      message: `Synced ${matches.length} fixtures (${upcomingCount} upcoming)`,
    };
  } catch (error: unknown) {
    const err = error as { response?: { status: number; data: string }; message?: string };
    functions.logger.error('Fixture sync failed', { error: err?.message });
    throw new functions.https.HttpsError(
      'internal',
      `Fixture sync failed: ${err?.response?.data ?? err?.message ?? 'Unknown error'}`
    );
  }
});

export const updateFixtureStatus = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async () => {
    try {
      const response = await axios.get(
        'https://api.football-data.org/v4/competitions/PL/matches?status=FINISHED,IN_PLAY,PAUSED,HALFTIME&limit=50',
        {
          headers: { 'X-Auth-Token': FOOTBALL_DATA_API_KEY },
          timeout: 10000,
        }
      );

      const matches = response.data.matches as FootballDataMatch[];
      if (!matches || matches.length === 0) return null;

      const batch = db.batch();

      for (const match of matches) {
        const status = mapStatus(match.status);
        const ref = db.collection('fixtures').doc(match.id.toString());
        batch.set(
          ref,
          {
            status,
            homeScore: match.score.fullTime.home,
            awayScore: match.score.fullTime.away,
          },
          { merge: true }
        );
      }

      await batch.commit();
      functions.logger.info(`Updated ${matches.length} fixture statuses`);
      return null;
    } catch (error: unknown) {
      const err = error as { message?: string };
      functions.logger.error('Fixture status update failed', { error: err?.message });
      return null;
    }
  });