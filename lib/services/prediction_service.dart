import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fixture_model.dart';
import '../models/prediction_model.dart';
import 'badge_service.dart';

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

  Future<PredictionModel?> getPrediction(
      String userId, String fixtureId) async {
    final snap =
        await _db.collection('predictions').doc(_docId(userId, fixtureId)).get();
    if (!snap.exists) return null;
    return PredictionModel.fromFirestore(snap.data()!, snap.id);
  }
}
