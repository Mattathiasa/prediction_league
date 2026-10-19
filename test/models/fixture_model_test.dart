import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_league/models/fixture_model.dart';

void main() {
  group('FixtureModel', () {
    late DateTime futureKickoff;
    late DateTime pastKickoff;

    setUp(() {
      futureKickoff = DateTime.now().add(const Duration(days: 1));
      pastKickoff = DateTime.now().subtract(const Duration(days: 1));
    });

    test('isLocked returns true within 1 hour of kickoff', () {
      final lockedKickoff = DateTime.now().add(const Duration(minutes: 30));
      final fixture = FixtureModel(
        fixtureId: '1',
        homeTeam: 'Arsenal',
        awayTeam: 'Chelsea',
        kickoff: lockedKickoff,
        status: 'upcoming',
        competition: 'Premier League',
      );
      expect(fixture.isLocked, true);
    });

    test('isLocked returns false more than 1 hour before kickoff', () {
      final fixture = FixtureModel(
        fixtureId: '1',
        homeTeam: 'Arsenal',
        awayTeam: 'Chelsea',
        kickoff: futureKickoff,
        status: 'upcoming',
        competition: 'Premier League',
      );
      expect(fixture.isLocked, false);
    });

    test('isFinished returns correct status', () {
      expect(
        FixtureModel(
          fixtureId: '1',
          homeTeam: 'Arsenal',
          awayTeam: 'Chelsea',
          kickoff: pastKickoff,
          status: 'finished',
          competition: 'Premier League',
        ).isFinished,
        true,
      );
      expect(
        FixtureModel(
          fixtureId: '1',
          homeTeam: 'Arsenal',
          awayTeam: 'Chelsea',
          kickoff: futureKickoff,
          status: 'upcoming',
          competition: 'Premier League',
        ).isFinished,
        false,
      );
    });

    test('isLive returns correct status', () {
      expect(
        FixtureModel(
          fixtureId: '1',
          homeTeam: 'Arsenal',
          awayTeam: 'Chelsea',
          kickoff: futureKickoff,
          status: 'live',
          competition: 'Premier League',
        ).isLive,
        true,
      );
    });

    test('isUpcoming returns correct status', () {
      expect(
        FixtureModel(
          fixtureId: '1',
          homeTeam: 'Arsenal',
          awayTeam: 'Chelsea',
          kickoff: futureKickoff,
          status: 'upcoming',
          competition: 'Premier League',
        ).isUpcoming,
        true,
      );
    });
  });
}
