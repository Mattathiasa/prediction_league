import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ScoringService {
  // ── Core scoring logic ────────────────────────────────────────────────────

  static int calculatePoints({
    required int homeGuess,
    required int awayGuess,
    required int homeScore,
    required int awayScore,
  }) {
    // Exact scoreline: 5 pts
    if (homeGuess == homeScore && awayGuess == awayScore) return 5;

    final guessOutcome = _outcome(homeGuess, awayGuess);
    final actualOutcome = _outcome(homeScore, awayScore);

    if (guessOutcome == actualOutcome) {
      // Correct result + correct goal difference: 3 pts
      if ((homeGuess - awayGuess) == (homeScore - awayScore)) return 3;
      // Correct result only: 1 pt
      return 1;
    }

    // Wrong result: 0 pts
    return 0;
  }

  static String _outcome(int home, int away) {
    if (home > away) return 'home';
    if (away > home) return 'away';
    return 'draw';
  }

  // ── Display helpers ───────────────────────────────────────────────────────

  static String pointsLabel(int points) {
    switch (points) {
      case 5:
        return 'Exact score!';
      case 3:
        return 'Right result + GD';
      case 1:
        return 'Right result';
      case 0:
        return 'Wrong result';
      case -1:
        return 'No prediction';
      default:
        return '$points pts';
    }
  }

  static Color pointsColor(int points) {
    if (points == 5) return AppColors.gold;
    if (points == 3) return AppColors.info;
    if (points == 1) return AppColors.accent;
    if (points == 0) return AppColors.live;
    return Colors.white38; // -1 or unknown
  }
}
