import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_league/models/matchup_model.dart';
import 'package:prediction_league/models/user_model.dart';

void main() {
  group('LeagueMatchup', () {
    test('bye matchup returns BYE for resultText', () {
      const matchup = LeagueMatchup(
        home: UserModel(uid: '1', displayName: 'A', photoUrl: ''),
        isBye: true,
      );
      expect(matchup.resultText, 'BYE');
      expect(matchup.isBye, true);
    });

    test('home win returns W for resultText', () {
      const matchup = LeagueMatchup(
        home: UserModel(
          uid: '1',
          displayName: 'A',
          photoUrl: '',
          weeklyPoints: 20,
        ),
        away: UserModel(
          uid: '2',
          displayName: 'B',
          photoUrl: '',
          weeklyPoints: 10,
        ),
      );
      expect(matchup.resultText, 'W');
      expect(matchup.homeWon, true);
    });
  });
}
