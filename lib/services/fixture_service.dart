import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/fixture_model.dart';

class FixtureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Cloud Functions (secure API key, admin-only) ────────────────────────────

  /// Calls the `syncFixtures` Cloud Function (admin-only).
  /// Fetches upcoming fixtures from football-data.org (server-side),
  /// batch-writes to Firestore, and returns the upcoming fixtures list.
  Future<List<FixtureModel>> syncFixtures() async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('syncFixtures');
    await callable();

    // After sync, read upcoming fixtures from Firestore
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

  /// Calls `scoreFixtureResults` Cloud Function (admin-only).
  /// Batch-scores all predictions and updates user stats atomically.
  Future<int?> scoreFixtureResults({
    required String fixtureId,
    required int homeScore,
    required int awayScore,
    String? currentUserId,
  }) async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('scoreFixtureResults');
    final result = await callable({
      'fixtureId': fixtureId,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'currentUserId': currentUserId,
    });
    final pts = result.data['pointsEarned'] as int?;
    return pts;
  }

  // Live/finished fixture updates are handled by the scheduled Cloud Function
  // `updateFixtureStatus` (runs every 10 minutes during match hours).
  // No client-side API call needed — the Firestore stream updates automatically.

  // Real-time stream from Firestore — no API call needed.
  Stream<List<FixtureModel>> upcomingFixtures() {
    return _db
        .collection('fixtures')
        .where('status', isEqualTo: 'upcoming')
        .orderBy('kickoff')
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FixtureModel.fromFirestore(d.data(), d.id))
            .toList());
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
