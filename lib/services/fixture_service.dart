import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/fixture_model.dart';

class FixtureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Calls the Cloud Function to sync fixtures from football-data.org.
  // Returns only upcoming fixtures so the caller can schedule notifications.
  Future<List<FixtureModel>> syncFixtures() async {
    try {
      final result = await _functions.httpsCallable('syncFixtures').call();
      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Fixture sync failed');
      }

      // Fetch the upcoming fixtures from Firestore after sync
      final snap = await _db
          .collection('fixtures')
          .where('status', isEqualTo: 'upcoming')
          .orderBy('kickoff')
          .limit(20)
          .get();

      return snap.docs
          .map((d) => FixtureModel.fromFirestore(d.data(), d.id))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Fixture sync failed: ${e.message}');
    }
  }

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
  // Uses whereIn so no composite index needed (no orderBy on server).
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
  // Single-field where clause — auto-indexed, no composite index required.
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