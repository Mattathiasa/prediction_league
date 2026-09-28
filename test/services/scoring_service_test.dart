import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_league/services/scoring_service.dart';

void main() {
  group('ScoringService', () {
    test('exact score returns 5 points', () {
      expect(
          ScoringService.calculatePoints(
              homeGuess: 2, awayGuess: 1, homeScore: 2, awayScore: 1),
          5);
      expect(
          ScoringService.calculatePoints(
              homeGuess: 0, awayGuess: 0, homeScore: 0, awayScore: 0),
          5);
      expect(
          ScoringService.calculatePoints(
              homeGuess: 3, awayGuess: 2, homeScore: 3, awayScore: 2),
          5);
    });

    test('correct result with correct goal difference returns 3 points', () {
      expect(
          ScoringService.calculatePoints(
              homeGuess: 3, awayGuess: 1, homeScore: 2, awayScore: 0),
          3);
      expect(
          ScoringService.calculatePoints(
              homeGuess: 1, awayGuess: 3, homeScore: 0, awayScore: 2),
          3);
      expect(
          ScoringService.calculatePoints(
              homeGuess: 2, awayGuess: 2, homeScore: 1, awayScore: 1),
          3);
      // home win, same goal difference
      expect(
          ScoringService.calculatePoints(
              homeGuess: 2, awayGuess: 1, homeScore: 1, awayScore: 0),
          3);
      // away win, same goal difference
      expect(
          ScoringService.calculatePoints(
              homeGuess: 0, awayGuess: 2, homeScore: 1, awayScore: 3),
          3);
      // predicted draw 0-0, actual draw 1-1: right result, same goal difference
      expect(
          ScoringService.calculatePoints(
              homeGuess: 0, awayGuess: 0, homeScore: 1, awayScore: 1),
          3);
    });

    test('correct result only returns 1 point', () {
      // home win, different goal difference
      expect(
          ScoringService.calculatePoints(
              homeGuess: 1, awayGuess: 0, homeScore: 3, awayScore: 1),
          1);
      // away win, different goal difference
      expect(
          ScoringService.calculatePoints(
              homeGuess: 0, awayGuess: 1, homeScore: 1, awayScore: 3),
          1);
      // A draw always has a goal difference of 0, so a correctly-predicted
      // draw can never score 1 — it is always an exact score or a 3.
    });

    test('wrong result returns 0 points', () {
      // predicted home win, actual away win
      expect(
          ScoringService.calculatePoints(
              homeGuess: 2, awayGuess: 1, homeScore: 1, awayScore: 2),
          0);
      // predicted home win, actual away win
      expect(
          ScoringService.calculatePoints(
              homeGuess: 3, awayGuess: 0, homeScore: 0, awayScore: 3),
          0);
      // predicted away win, actual home win
      expect(
          ScoringService.calculatePoints(
              homeGuess: 0, awayGuess: 2, homeScore: 2, awayScore: 0),
          0);
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
}
