import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_league/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('defaults isPremium to false', () {
      const user = UserModel(uid: '1', displayName: 'Test', photoUrl: '');
      expect(user.isPremium, false);
      expect(user.predictionsCount, 0);
      expect(user.exactScoreCount, 0);
      expect(user.highestWeeklyPoints, 0);
    });

    test('toMap includes isPremium', () {
      const user = UserModel(
        uid: '1',
        displayName: 'Test',
        photoUrl: 'http://example.com',
        isPremium: true,
        totalPoints: 100,
      );
      final map = user.toMap();
      expect(map['isPremium'], true);
      expect(map['uid'], '1');
      expect(map['totalPoints'], 100);
    });

    test('copyWith preserves isPremium', () {
      const user = UserModel(
        uid: '1',
        displayName: 'Test',
        photoUrl: '',
        isPremium: true,
      );
      final copied = user.copyWith(displayName: 'Updated');
      expect(copied.isPremium, true);
      expect(copied.displayName, 'Updated');
    });
  });
}
