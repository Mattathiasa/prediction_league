import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../models/fixture_model.dart';
import 'badge_service.dart';
import 'scoring_service.dart';

/// Fixture sync and admin scoring, for the Spark-plan deployment.
///
/// These operations used to be Cloud Functions (`syncFixtures`,
/// `updateFixtureStatus`, `scoreFixtureResults`) running under the Admin SDK,
/// with the football-data.org key injected via Secret Manager and never
/// reaching the client. Cloud Functions require the Blaze plan to deploy at
/// all, so this project — which stays on Spark — ports the same logic to run
/// directly on the admin's device instead. `functions/src/index.ts` keeps the
/// original server-authoritative versions, tested but not deployed.
///
/// Two accepted trade-offs from that move (see README's "Project status"):
/// the API key is now compiled into the client (passed via `--dart-define`,
/// never committed — see Setup), and there's no scheduled background
/// refresh, only this manual "sync now" action. Scoring trusts the admin's
/// own device and firestore.rules' bounded checks rather than a full
/// server-side recomputation; see firestore.rules for exactly what's bounded.
class FixtureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _batchLimit = 500;
  static const String _competition = 'PL';
  static const String _apiKey = String.fromEnvironment('FOOTBALL_DATA_API_KEY');

  // ── football-data.org ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _apiRequest(String path) async {
    final uri = Uri.https('api.football-data.org', '/v4/$path');
    final response = await http.get(
      uri,
      headers: {
        'X-Auth-Token': _apiKey,
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static String _mapApiStatus(String raw) {
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

  static Map<String, dynamic> _parseFixtureRaw(Map<String, dynamic> raw) {
    final home = raw['homeTeam'] as Map<String, dynamic>;
    final away = raw['awayTeam'] as Map<String, dynamic>;
    final score = (raw['score'] as Map<String, dynamic>?)?['fullTime']
            as Map<String, dynamic>? ??
        const {};
    return {
      'fixtureId': raw['id'].toString(),
      'homeTeam': (home['shortName'] ?? home['name']) as String,
      'awayTeam': (away['shortName'] ?? away['name']) as String,
      'kickoff': Timestamp.fromDate(DateTime.parse(raw['utcDate'] as String)),
      'homeScore': score['home'] as int?,
      'awayScore': score['away'] as int?,
      'status': _mapApiStatus(raw['status'] as String),
      'competition': 'Premier League',
    };
  }

  /// Manual "sync now" admin action — pulls upcoming, live and finished
  /// fixtures from football-data.org and writes them to Firestore. Replaces
  /// both `syncFixtures` and the every-10-minutes `updateFixtureStatus`
  /// schedule; there is no background refresh, only this.
  Future<List<FixtureModel>> syncFixtures() async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'football-data.org API key not configured — pass '
        '--dart-define=FOOTBALL_DATA_API_KEY=... when building. See README.',
      );
    }

    final batch = _db.batch();

    final upcoming = await _apiRequest(
      'competitions/$_competition/matches?status=SCHEDULED,TIMED&limit=50',
    );
    for (final raw in (upcoming['matches'] as List? ?? const [])) {
      final fixture = _parseFixtureRaw(raw as Map<String, dynamic>);
      batch.set(
        _db.collection('fixtures').doc(fixture['fixtureId'] as String),
        fixture,
        SetOptions(merge: true),
      );
    }

    final liveFinished = await _apiRequest(
      'competitions/$_competition/matches?status=FINISHED,IN_PLAY,PAUSED,HALFTIME&limit=100',
    );
    for (final raw in (liveFinished['matches'] as List? ?? const [])) {
      final fixture = _parseFixtureRaw(raw as Map<String, dynamic>);
      batch.set(
        _db.collection('fixtures').doc(fixture['fixtureId'] as String),
        fixture,
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    final snap = await _db
        .collection('fixtures')
        .where('status', isEqualTo: 'upcoming')
        .orderBy('kickoff')
        .limit(20)
        .get();

    return snap.docs
        .map((d) => FixtureModel.fromFirestore(d.data(), d.id))
        .toList();
  }

  // ── Admin scoring ────────────────────────────────────────────────────────

  static const int _onFireStreak = 5;

  Future<void> _commitInChunks(
    List<void Function(WriteBatch)> ops,
  ) async {
    for (var i = 0; i < ops.length; i += _batchLimit) {
      final batch = _db.batch();
      final end = (i + _batchLimit).clamp(0, ops.length);
      for (final op in ops.sublist(i, end)) {
        op(batch);
      }
      await batch.commit();
    }
  }

  /// Derived from a user's full scored history rather than incremented, so
  /// re-running this can never double-award a badge.
  List<String> _earnedBadges(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> predictions,
  ) {
    if (predictions.isEmpty) return [];

    final ordered = [...predictions]..sort((a, b) {
        final aTime =
            (a.data()['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                0;
        final bTime =
            (b.data()['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                0;
        return aTime.compareTo(bTime);
      });

    final badges = <String>[BadgeService.firstKick];

    if (ordered.any((p) => (p.data()['pointsEarned'] as int? ?? 0) == 5)) {
      badges.add(BadgeService.sniper);
    }

    var streak = 0;
    for (final p in ordered) {
      streak = (p.data()['pointsEarned'] as int? ?? 0) > 0 ? streak + 1 : 0;
      if (streak >= _onFireStreak) {
        badges.add(BadgeService.onFire);
        break;
      }
    }

    return badges;
  }

  /// Scores every prediction for a fixture and credits its authors.
  ///
  /// Ported from the `scoreFixtureResults` Cloud Function with the same
  /// ordering: score predictions and credit authors first, penalize
  /// non-predictors second, award badges third, and mark the fixture
  /// `finished` **last** — a failure at any earlier step leaves the fixture
  /// safely re-runnable, since the idempotency guard below reads that flag.
  ///
  /// Known limitation carried over unchanged from the reference
  /// implementation: there is no reliable `createdAt` on user documents, so
  /// the "don't penalize users who signed up after kickoff" exemption the
  /// comment in `functions/src/index.ts` describes never actually applied —
  /// every signed-in user without a prediction is penalized.
  Future<int?> scoreFixtureResults({
    required String fixtureId,
    required int homeScore,
    required int awayScore,
    String? currentUserId,
  }) async {
    final fixtureRef = _db.collection('fixtures').doc(fixtureId);
    final fixtureSnap = await fixtureRef.get();
    if (!fixtureSnap.exists) {
      throw Exception('Fixture not found');
    }
    if (fixtureSnap.data()?['status'] == 'finished') {
      return null; // Already scored.
    }

    final predSnap = await _db
        .collection('predictions')
        .where('fixtureId', isEqualTo: fixtureId)
        .get();

    final predictedUids = <String>{};
    final pointsByUser = <String, int>{};

    for (final doc in predSnap.docs) {
      final data = doc.data();
      final userId = data['userId'] as String;
      predictedUids.add(userId);
      pointsByUser[userId] = ScoringService.calculatePoints(
        homeGuess: data['homeGuess'] as int,
        awayGuess: data['awayGuess'] as int,
        homeScore: homeScore,
        awayScore: awayScore,
      );
    }

    // ── 1. Score predictions and credit their authors ────────────────────
    final scoringOps = <void Function(WriteBatch)>[];

    for (final doc in predSnap.docs) {
      final points = pointsByUser[doc.data()['userId']]!;
      scoringOps.add(
        (b) => b.update(doc.reference, {
          'pointsEarned': points,
          'locked': true,
        }),
      );
    }

    for (final entry in pointsByUser.entries) {
      scoringOps.add(
        (b) => b.update(_db.collection('users').doc(entry.key), {
          'totalPoints': FieldValue.increment(entry.value),
          'weeklyPoints': FieldValue.increment(entry.value),
        }),
      );
      scoringOps.add(
        (b) => b.update(_db.collection('publicProfiles').doc(entry.key), {
          'totalPoints': FieldValue.increment(entry.value),
          'weeklyPoints': FieldValue.increment(entry.value),
        }),
      );
    }

    await _commitInChunks(scoringOps);

    // ── 2. Penalize everyone who didn't predict ──────────────────────────
    final usersSnap = await _db.collection('users').get();
    final penaltyOps = <void Function(WriteBatch)>[];

    for (final userDoc in usersSnap.docs) {
      if (predictedUids.contains(userDoc.id)) continue;

      penaltyOps.add(
        (b) => b.update(userDoc.reference, {
          'totalPoints': FieldValue.increment(-1),
          'weeklyPoints': FieldValue.increment(-1),
        }),
      );
      penaltyOps.add(
        (b) => b.update(
          _db.collection('publicProfiles').doc(userDoc.id),
          {
            'totalPoints': FieldValue.increment(-1),
            'weeklyPoints': FieldValue.increment(-1),
          },
        ),
      );
    }

    await _commitInChunks(penaltyOps);

    // ── 3. Award badges ───────────────────────────────────────────────────
    await Future.wait(predictedUids.map(_awardBadgesTo));

    // ── 4. Mark the fixture finished, last ────────────────────────────────
    await fixtureRef.update({
      'homeScore': homeScore,
      'awayScore': awayScore,
      'status': 'finished',
    });

    return pointsByUser[currentUserId];
  }

  Future<void> _awardBadgesTo(String userId) async {
    final history = await _db
        .collection('predictions')
        .where('userId', isEqualTo: userId)
        .where('locked', isEqualTo: true)
        .get();
    final badges = _earnedBadges(history.docs);
    if (badges.isEmpty) return;

    final badgeBatch = _db.batch();
    badgeBatch.update(_db.collection('users').doc(userId), {
      'badgeIds': FieldValue.arrayUnion(badges),
    });
    badgeBatch.update(_db.collection('publicProfiles').doc(userId), {
      'badgeIds': FieldValue.arrayUnion(badges),
    });
    await badgeBatch.commit();
  }

  // ── Reads ─────────────────────────────────────────────────────────────────

  Stream<List<FixtureModel>> upcomingFixtures() {
    return _db
        .collection('fixtures')
        .where('status', isEqualTo: 'upcoming')
        .orderBy('kickoff')
        .limit(20)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => FixtureModel.fromFirestore(d.data(), d.id))
              .toList(),
        );
  }

  Future<FixtureModel?> getFixture(String fixtureId) async {
    final snap = await _db.collection('fixtures').doc(fixtureId).get();
    if (!snap.exists) return null;
    return FixtureModel.fromFirestore(snap.data()!, snap.id);
  }

  // Admin: all non-finished fixtures, sorted by kickoff client-side.
  Stream<List<FixtureModel>> adminFixtures() {
    return _db
        .collection('fixtures')
        .where('status', whereIn: ['upcoming', 'live'])
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => FixtureModel.fromFirestore(d.data(), d.id))
              .toList()
            ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
          return list;
        });
  }

  // Results screen: finished fixtures, newest first, client-side sort.
  Stream<List<FixtureModel>> finishedFixtures() {
    return _db
        .collection('fixtures')
        .where('status', isEqualTo: 'finished')
        .limit(30)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => FixtureModel.fromFirestore(d.data(), d.id))
          .toList()
        ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
      return list;
    });
  }
}
