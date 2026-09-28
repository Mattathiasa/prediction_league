import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_league/models/prediction_model.dart';

void main() {
  group('PredictionModel', () {
    test('copyWith updates fields correctly', () {
      final original = PredictionModel(
        predictionId: '1',
        userId: 'user1',
        fixtureId: 'fixture1',
        homeGuess: 1,
        awayGuess: 0,
        pointsEarned: 0,
        submittedAt: DateTime.now(),
        locked: false,
      );

      final updated = original.copyWith(
          homeGuess: 2, awayGuess: 1, pointsEarned: 3, locked: true);

      expect(updated.homeGuess, 2);
      expect(updated.awayGuess, 1);
      expect(updated.pointsEarned, 3);
      expect(updated.locked, true);
      expect(updated.predictionId, original.predictionId);
      expect(updated.userId, original.userId);
      expect(updated.fixtureId, original.fixtureId);
      expect(updated.submittedAt, original.submittedAt);
    });

    test('toMap and fromFirestore round-trip', () {
      final submittedAt = DateTime.now();
      final original = PredictionModel(
        predictionId: '1',
        userId: 'user1',
        fixtureId: 'fixture1',
        homeGuess: 2,
        awayGuess: 1,
        pointsEarned: 3,
        submittedAt: submittedAt,
        locked: true,
      );

      final map = original.toMap();
      final restored = PredictionModel.fromFirestore(map, '1');

      expect(restored.predictionId, '1');
      expect(restored.userId, 'user1');
      expect(restored.fixtureId, 'fixture1');
      expect(restored.homeGuess, 2);
      expect(restored.awayGuess, 1);
      expect(restored.pointsEarned, 3);
      expect(restored.locked, true);
      expect(restored.submittedAt.millisecondsSinceEpoch,
          submittedAt.millisecondsSinceEpoch);
    });
  });
}
