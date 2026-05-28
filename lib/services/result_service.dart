import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'badge_service.dart';
import 'scoring_service.dart';

class ResultService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BadgeService _badges = BadgeService();

  /// Scores all predictions for a fixture.
  /// Returns the current user's points if [currentUserId] is provided.
  Future<int?> submitResult({
    required String fixtureId,
    required int homeScore,
    required int awayScore,
    String? currentUserId,
  }) async {
    // ── 1. Parallel reads ─────────────────────────────────────────────────
    final predFuture = _db
        .collection('predictions')
        .where('fixtureId', isEqualTo: fixtureId)
        .get();
    final usersFuture = _db.collection('users').get();

    final predSnap = await predFuture;
    final usersSnap = await usersFuture;

    final predictedUids =
        predSnap.docs.map((d) => d.data()['userId'] as String).toSet();

    // ── 2. Build batch ────────────────────────────────────────────────────
    final batch = _db.batch();

    batch.update(_db.collection('fixtures').doc(fixtureId), {
      'homeScore': homeScore,
      'awayScore': awayScore,
      'status': 'finished',
    });

    int? currentUserPoints;

    for (final doc in predSnap.docs) {
      final data = doc.data();
      final userId = data['userId'] as String;
      final points = ScoringService.calculatePoints(
        homeGuess: data['homeGuess'] as int,
        awayGuess: data['awayGuess'] as int,
        homeScore: homeScore,
        awayScore: awayScore,
      );

      batch.update(doc.reference, {'pointsEarned': points, 'locked': true});
      batch.update(_db.collection('users').doc(userId), {
        'totalPoints': FieldValue.increment(points),
        'weeklyPoints': FieldValue.increment(points),
      });

      if (userId == currentUserId) currentUserPoints = points;
    }

    // -1 for non-predictors
    for (final userDoc in usersSnap.docs) {
      if (!predictedUids.contains(userDoc.id)) {
        batch.update(userDoc.reference, {
          'totalPoints': FieldValue.increment(-1),
          'weeklyPoints': FieldValue.increment(-1),
        });
      }
    }

    // ── 3. Commit ─────────────────────────────────────────────────────────
    await batch.commit();

    // ── 4. Post-commit: accuracy, streak, badges (non-blocking per user) ──
    await Future.wait(predictedUids.map(_recalcUserStats));
    await Future.wait(predictedUids.map(_badges.checkAndAwardPostResultBadges));

    return currentUserPoints;
  }

  // Updates accuracy, currentStreak, and bestStreak from all scored predictions
  Future<void> _recalcUserStats(String userId) async {
    final snap = await _db
        .collection('predictions')
        .where('userId', isEqualTo: userId)
        .where('locked', isEqualTo: true)
        .get();

    if (snap.docs.isEmpty) return;

    final preds = snap.docs.map((d) => d.data()).toList()
      ..sort((a, b) {
        final ta = (a['submittedAt'] as Timestamp).millisecondsSinceEpoch;
        final tb = (b['submittedAt'] as Timestamp).millisecondsSinceEpoch;
        return ta.compareTo(tb);
      });

    final total = preds.length;
    final correct =
        preds.where((p) => (p['pointsEarned'] as int? ?? 0) > 0).length;
    final accuracy = (correct / total) * 100;

    // Current streak: consecutive correct predictions from the most recent
    int currentStreak = 0;
    for (int i = preds.length - 1; i >= 0; i--) {
      if ((preds[i]['pointsEarned'] as int? ?? 0) > 0) {
        currentStreak++;
      } else {
        break;
      }
    }

    // Best streak ever
    int bestStreak = 0;
    int run = 0;
    for (final p in preds) {
      if ((p['pointsEarned'] as int? ?? 0) > 0) {
        run++;
        bestStreak = max(bestStreak, run);
      } else {
        run = 0;
      }
    }

    await _db.collection('users').doc(userId).update({
      'accuracy': double.parse(accuracy.toStringAsFixed(1)),
      'streak': currentStreak,
      'bestStreak': bestStreak,
    });
  }
}
