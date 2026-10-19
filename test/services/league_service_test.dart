import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_league/models/user_model.dart';
import 'package:prediction_league/services/league_service.dart';

UserModel member(String uid, {int weekly = 0, int total = 0}) => UserModel(
      uid: uid,
      displayName: uid,
      photoUrl: '',
      weeklyPoints: weekly,
      totalPoints: total,
    );

void main() {
  group('generateInviteCode', () {
    test('produces six uppercase alphanumeric characters', () {
      for (var i = 0; i < 50; i++) {
        expect(
          LeagueService.generateInviteCode(),
          matches(RegExp(r'^[A-Z0-9]{6}$')),
        );
      }
    });

    test('does not repeat across a large sample', () {
      final codes =
          List.generate(500, (_) => LeagueService.generateInviteCode());
      // 36^6 ≈ 2.2bn, so 500 draws colliding would indicate a broken RNG.
      expect(codes.toSet().length, 500);
    });
  });

  group('generateMatchups', () {
    test('pairs top seed against bottom seed', () {
      final matchups = LeagueService.generateMatchups([
        member('a', weekly: 10),
        member('b', weekly: 8),
        member('c', weekly: 6),
        member('d', weekly: 4),
      ]);

      expect(matchups, hasLength(2));
      expect(matchups[0].home.uid, 'a');
      expect(matchups[0].away!.uid, 'd');
      expect(matchups[1].home.uid, 'b');
      expect(matchups[1].away!.uid, 'c');
      expect(matchups.every((m) => !m.isBye), isTrue);
    });

    test('gives the middle seed a bye when the league is odd', () {
      final matchups = LeagueService.generateMatchups([
        member('a', weekly: 10),
        member('b', weekly: 8),
        member('c', weekly: 6),
        member('d', weekly: 4),
        member('e', weekly: 2),
      ]);

      expect(matchups, hasLength(3));
      final byes = matchups.where((m) => m.isBye).toList();
      expect(byes, hasLength(1));
      expect(byes.single.home.uid, 'c');
      expect(byes.single.away, isNull);
    });

    test('every member appears exactly once', () {
      final members = List.generate(9, (i) => member('u$i', weekly: 9 - i));
      final matchups = LeagueService.generateMatchups(members);

      final seen = <String>[];
      for (final m in matchups) {
        seen.add(m.home.uid);
        if (m.away != null) seen.add(m.away!.uid);
      }

      expect(seen..sort(), members.map((m) => m.uid).toList()..sort());
    });

    test('breaks weeklyPoints ties on totalPoints', () {
      final matchups = LeagueService.generateMatchups([
        member('low', weekly: 5, total: 10),
        member('high', weekly: 5, total: 90),
      ]);

      expect(matchups.single.home.uid, 'high');
      expect(matchups.single.away!.uid, 'low');
    });

    test('a single member gets a bye', () {
      final matchups = LeagueService.generateMatchups([member('solo')]);
      expect(matchups, hasLength(1));
      expect(matchups.single.isBye, isTrue);
    });

    test('an empty league produces no matchups', () {
      expect(LeagueService.generateMatchups([]), isEmpty);
    });

    test('does not mutate the caller\'s list', () {
      final members = [member('a', weekly: 1), member('b', weekly: 9)];
      final original = members.map((m) => m.uid).toList();
      LeagueService.generateMatchups(members);
      expect(members.map((m) => m.uid).toList(), original);
    });
  });
}
