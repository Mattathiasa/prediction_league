import 'package:flutter/material.dart';

/// The app's colour palette.
///
/// Every colour the UI uses lives here. Before this existed the same fifteen
/// literals were repeated roughly 190 times across fourteen files — `0xFF4CAF50`
/// alone appeared 98 times — which meant a palette change was a find-and-replace
/// and two screens had already drifted apart.
abstract final class AppColors {
  // ── Surfaces ───────────────────────────────────────────────────────────────

  /// Page background.
  static const background = Color(0xFF0F0F1A);

  /// Cards, sheets, dialogs — one step above [background].
  static const surface = Color(0xFF1A1A2E);

  /// Dividers and inactive outlines.
  static const outline = Color(0xFF333344);

  // ── Brand ──────────────────────────────────────────────────────────────────

  /// Primary accent: actions, focus, positive results.
  static const accent = Color(0xFF4CAF50);

  /// Google's brand blue, used only on the sign-in button.
  static const googleBlue = Color(0xFF4285F4);

  /// Google's brand foreground for the light sign-in button.
  static const googleForeground = Color(0xFF1F1F1F);

  // ── Hero gradient ──────────────────────────────────────────────────────────

  static const gradientStart = Color(0xFF1E3A5F);
  static const gradientEnd = Color(0xFF0D2137);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  // ── Podium ─────────────────────────────────────────────────────────────────

  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFBDBDBD);
  static const bronze = Color(0xFFCD7F32);

  /// Colour for a leaderboard rank. Ranks are 1-based; anything outside the
  /// podium renders in muted text.
  ///
  /// Previously duplicated in two screens with *different* behaviour — one
  /// returned bronze for every rank past third, the other returned muted. This
  /// is the muted version, which is what the design intends.
  static Color forRank(int rank) => switch (rank) {
        1 => gold,
        2 => silver,
        3 => bronze,
        _ => textSecondary,
      };

  // ── Status ─────────────────────────────────────────────────────────────────

  /// A match currently in play.
  static const live = Color(0xFFFF7043);

  /// Informational highlights.
  static const info = Color(0xFF29B6F6);

  /// Destructive actions.
  static const danger = Color(0xFFB71C1C);

  /// Premium / subscription accents.
  static const premium = Color(0xFF9C27B0);

  // ── Text ───────────────────────────────────────────────────────────────────

  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white70;
  static const textMuted = Colors.white54;
  static const textDisabled = Colors.white38;
  static const textFaint = Colors.white24;
}
