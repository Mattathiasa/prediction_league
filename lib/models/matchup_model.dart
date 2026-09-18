import '../models/user_model.dart';

class LeagueMatchup {
  final UserModel home;
  final UserModel? away;
  final bool isBye;

  LeagueMatchup({required this.home, this.away, this.isBye = false});

  int get homePoints => home.weeklyPoints;
  int get awayPoints => away?.weeklyPoints ?? 0;

  String get resultText {
    if (isBye) return 'BYE';
    if (homePoints > awayPoints) return 'W';
    if (homePoints < awayPoints) return 'L';
    return 'D';
  }

  bool get homeWon => !isBye && homePoints > awayPoints;
  bool get awayWon => !isBye && homePoints < awayPoints;
  bool get isDraw => !isBye && homePoints == awayPoints;
}
