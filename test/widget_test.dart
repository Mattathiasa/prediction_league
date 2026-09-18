import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_league/models/fixture_model.dart';
import 'package:prediction_league/models/prediction_model.dart';
import 'package:prediction_league/services/scoring_service.dart';

void main() {
  group('ScoringService', () {
    test('exact score returns 5 points', () {
      expect(ScoringService.calculatePoints(homeGuess: 2, awayGuess: 1, homeScore: 2, awayScore: 1), 5);
      expect(ScoringService.calculatePoints(homeGuess: 0, awayGuess: 0, homeScore: 0, awayScore: 0), 5);
      expect(ScoringService.calculatePoints(homeGuess: 3, awayGuess: 2, homeScore: 3, awayScore: 2), 5);
    });

    test('correct result with correct goal difference returns 3 points', () {
      expect(ScoringService.calculatePoints(homeGuess: 3, awayGuess: 1, homeScore: 2, awayScore: 0), 3);
      expect(ScoringService.calculatePoints(homeGuess: 1, awayGuess: 3, homeScore: 0, awayScore: 2), 3);
      expect(ScoringService.calculatePoints(homeGuess: 2, awayGuess: 2, homeScore: 1, awayScore: 1), 3);
      // home win, same goal difference
      expect(ScoringService.calculatePoints(homeGuess: 2, awayGuess: 1, homeScore: 1, awayScore: 0), 3);
      // away win, same goal difference
      expect(ScoringService.calculatePoints(homeGuess: 0, awayGuess: 2, homeScore: 1, awayScore: 3), 3);
    });

    test('correct result only returns 1 point', () {
      // home win, different goal difference
      expect(ScoringService.calculatePoints(homeGuess: 1, awayGuess: 0, homeScore: 3, awayScore: 1), 1);
      // away win, different goal difference
      expect(ScoringService.calculatePoints(homeGuess: 0, awayGuess: 1, homeScore: 1, awayScore: 3), 1);
      // draw, different goal difference (impossible for draw but testing logic)
    });

    test('wrong result returns 0 points', () {
      // predicted home win, actual away win
      expect(ScoringService.calculatePoints(homeGuess: 2, awayGuess: 1, homeScore: 1, awayScore: 2), 0);
      // predicted draw 0-0, actual draw 1-1 (correct result + correct GD = 3)
      expect(ScoringService.calculatePoints(homeGuess: 0, awayGuess: 0, homeScore: 1, awayScore: 1), 3);
      // predicted home win, actual away win
      expect(ScoringService.calculatePoints(homeGuess: 3, awayGuess: 0, homeScore: 0, awayScore: 3), 0);
      // predicted away win, actual home win
      expect(ScoringService.calculatePoints(homeGuess: 0, awayGuess: 2, homeScore: 2, awayScore: 0), 0);
    });

    test('pointsLabel returns correct labels', () {
      expect(ScoringService.pointsLabel(5), 'Exact score!');
      expect(ScoringService.pointsLabel(3), 'Right result + GD');
      expect(ScoringService.pointsLabel(1), 'Right result');
      expect(ScoringService.pointsLabel(0), 'Wrong result');
      expect(ScoringService.pointsLabel(-1), 'No prediction');
      expect(ScoringService.pointsLabel(99), '99 pts');
    });
  });

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

    test('fromApi parses football-data.org response correctly', () {
      final apiResponse = {
        'id': 12345,
        'utcDate': '2024-12-25T15:00:00Z',
        'status': 'SCHEDULED',
        'homeTeam': {'name': 'Arsenal FC', 'shortName': 'Arsenal'},
        'awayTeam': {'name': 'Chelsea FC', 'shortName': 'Chelsea'},
        'score': {'fullTime': {'home': null, 'away': null}},
        'competition': {'name': 'Premier League'},
      };

      final fixture = FixtureModel.fromApi(apiResponse);

      expect(fixture.fixtureId, '12345');
      expect(fixture.homeTeam, 'Arsenal');
      expect(fixture.awayTeam, 'Chelsea');
      expect(fixture.kickoff, DateTime.parse('2024-12-25T15:00:00Z'));
      expect(fixture.status, 'upcoming');
      expect(fixture.competition, 'Premier League');
    });

    test('fromApi parses finished match with scores', () {
      final apiResponse = {
        'id': 12345,
        'utcDate': '2024-12-25T15:00:00Z',
        'status': 'FINISHED',
        'homeTeam': {'name': 'Arsenal FC', 'shortName': 'Arsenal'},
        'awayTeam': {'name': 'Chelsea FC', 'shortName': 'Chelsea'},
        'score': {'fullTime': {'home': 2, 'away': 1}},
        'competition': {'name': 'Premier League'},
      };

      final fixture = FixtureModel.fromApi(apiResponse);

      expect(fixture.status, 'finished');
      expect(fixture.homeScore, 2);
      expect(fixture.awayScore, 1);
    });
  });

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

      final updated = original.copyWith(homeGuess: 2, awayGuess: 1, pointsEarned: 3, locked: true);

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
      expect(restored.submittedAt.millisecondsSinceEpoch, submittedAt.millisecondsSinceEpoch);
    });
  });
}