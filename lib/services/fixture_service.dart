import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import '../models/fixture_model.dart';

class FixtureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch from football-data.org, batch-write to Firestore, return the list.
  // Returns only upcoming fixtures so the caller can schedule notifications.
  Future<List<FixtureModel>> syncFixtures() async {
    final response = await http.get(
      Uri.parse(AppConfig.scheduledMatches),
      headers: AppConfig.apiHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'football-data.org error ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final matches = body['matches'] as List<dynamic>;

    if (matches.isEmpty) return [];

    final fixtures = matches
        .map((raw) => FixtureModel.fromApi(raw as Map<String, dynamic>))
        .toList();

    final batch = _db.batch();
    for (final fixture in fixtures) {
      batch.set(
        _db.collection('fixtures').doc(fixture.fixtureId),
        fixture.toMap(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    return fixtures.where((f) => f.isUpcoming).toList();
  }

  // Fetch live and finished matches to update fixtures already in Firestore
  // with current scores and statuses.
  Future<int> syncLiveAndFinished() async {
    final response = await http.get(
      Uri.parse(AppConfig.liveAndFinishedMatches),
      headers: AppConfig.apiHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'football-data.org error ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final matches = body['matches'] as List<dynamic>;

    if (matches.isEmpty) return 0;

    final batch = _db.batch();
    for (final raw in matches) {
      final fixture = FixtureModel.fromApi(raw as Map<String, dynamic>);
      batch.update(
        _db.collection('fixtures').doc(fixture.fixtureId),
        {
          'status': fixture.status,
          if (fixture.homeScore != null) 'homeScore': fixture.homeScore,
          if (fixture.awayScore != null) 'awayScore': fixture.awayScore,
        },
      );
    }
    await batch.commit();
    return matches.length;
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
