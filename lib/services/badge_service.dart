import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BadgeInfo {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const BadgeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class BadgeService {
  static const String firstKick = 'first_kick';
  static const String onFire = 'on_fire';
  static const String sniper = 'sniper';

  static const List<String> all = [firstKick, onFire, sniper];

  static BadgeInfo getInfo(String id) {
    switch (id) {
      case firstKick:
        return const BadgeInfo(
          id: firstKick,
          name: 'First Kick',
          description: 'Submitted your very first prediction',
          icon: Icons.sports_soccer,
          color: AppColors.accent,
        );
      case onFire:
        return const BadgeInfo(
          id: onFire,
          name: 'On Fire',
          description: '5 correct results in a row',
          icon: Icons.local_fire_department,
          color: AppColors.live,
        );
      case sniper:
        return const BadgeInfo(
          id: sniper,
          name: 'Sniper',
          description: 'Predicted an exact scoreline',
          icon: Icons.gps_fixed,
          color: AppColors.gold,
        );
      default:
        return BadgeInfo(
          id: id,
          name: id,
          description: '',
          icon: Icons.emoji_events,
          color: Colors.white38,
        );
    }
  }
}
