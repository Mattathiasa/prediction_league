import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fixture_model.dart';
import '../models/prediction_model.dart';
import 'badge_service.dart';

class HistoryEntry {
  final FixtureModel? fixture;
  final PredictionModel prediction;

  HistoryEntry({required this.fixture, required this.prediction});
}

class PredictionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BadgeService _badges = BadgeService();

  String _docId(String userId, String fixtureId) => '${userId}_$fixtureId';

  Future<void> submitPrediction({
    required String userId,
    required FixtureModel fixture,
    required int homeGuess,
    required int awayGuess,
  }) async {
    if (fixture.isLocked) {
      throw Exception('Prediction window is closed for this match.');
    }

    final docId = _docId(userId, fixture.fixtureId);
    final prediction = PredictionModel(
      predictionId: docId,
      userId: userId,
      fixtureId: fixture.fixtureId,
      homeGuess: homeGuess,
      awayGuess: awayGuess,
      submittedAt: DateTime.now(),
      locked: false,
    );

    await _db.collection('predictions').doc(docId).set(prediction.toMap());

    // Award first_kick badge if user doesn't have it yet
    _awardFirstKickIfNeeded(userId);
  }

  // Fire-and-forget — runs after the prediction is saved
  Future<void> _awardFirstKickIfNeeded(String userId) async {
    final userSnap = await _db.collection('users').doc(userId).get();
    final badges =
        List<String>.from(userSnap.data()?['badgeIds'] as List? ?? []);
    if (!badges.contains(BadgeService.firstKick)) {
      await _badges.awardBadge(userId, BadgeService.firstKick);
    }
  }

  Stream<List<PredictionModel>> userPredictions(String userId) {
    return _db
        .collection('predictions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PredictionModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  // Scored predictions only (locked == true), newest fixture first
  Stream<List<PredictionModel>> userScoredPredictions(String userId) {
    return _db
        .collection('predictions')
        .where('userId', isEqualTo: userId)
        .where('locked', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PredictionModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  // Combined stream: scored predictions joined with their fixtures
  // Uses combineLatestStreams pattern via transform
  Stream<List<HistoryEntry>> userHistory(String userId) {
    final predStream = userScoredPredictions(userId);
    final fixtureService = _FixtureLookup(_db);

    return predStream.asyncMap((predictions) async {
      if (predictions.isEmpty) return <HistoryEntry>[];

      final fixtureIds = predictions.map((p) => p.fixtureId).toSet().toList();
      final fixtures = await fixtureService.fetchByIds(fixtureIds);
      final fixtureMap = {for (final f in fixtures) f.fixtureId: f};

      final history = predictions
          .map((p) => HistoryEntry(
              fixture: fixtureMap[p.fixtureId], prediction: p))
          .toList()
        ..sort((a, b) {
          final aTime = a.fixture?.kickoff ?? a.prediction.submittedAt;
          final bTime = b.fixture?.kickoff ?? b.prediction.submittedAt;
          return bTime.compareTo(aTime);
        });

      return history;
    });
  }

  Future<PredictionModel?> getPrediction(
      String userId, String fixtureId) async {
    final snap =
        await _db.collection('predictions').doc(_docId(userId, fixtureId)).get();
    if (!snap.exists) return null;
    return PredictionModel.fromFirestore(snap.data()!, snap.id);
  }
}

// Helper to batch-fetch fixtures (respects Firestore whereIn limit of 10)
class _FixtureLookup {
  final FirebaseFirestore _db;
  _FixtureLookup(this._db);

  Future<List<FixtureModel>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final all = <FixtureModel>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10 > ids.length) ? ids.length : i + 10);
      final snap = await _db
          .collection('fixtures')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      all.addAll(snap.docs
          .map((d) => FixtureModel.fromFirestore(d.data(), d.id)));
    }
    return all;
  }
}
