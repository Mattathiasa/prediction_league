import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
          color: Color(0xFF4CAF50),
        );
      case onFire:
        return const BadgeInfo(
          id: onFire,
          name: 'On Fire',
          description: '5 correct results in a row',
          icon: Icons.local_fire_department,
          color: Color(0xFFFF7043),
        );
      case sniper:
        return const BadgeInfo(
          id: sniper,
          name: 'Sniper',
          description: 'Predicted an exact scoreline',
          icon: Icons.gps_fixed,
          color: Color(0xFFFFD700),
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

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Awards a badge (arrayUnion is idempotent — safe to call multiple times)
  Future<void> awardBadge(String userId, String badgeId) async {
    await _db.collection('users').doc(userId).update({
      'badgeIds': FieldValue.arrayUnion([badgeId]),
    });
  }

  // Called after a result is scored — checks on_fire and sniper for each userId
  Future<void> checkAndAwardPostResultBadges(String userId) async {
    final snap = await _db
        .collection('predictions')
        .where('userId', isEqualTo: userId)
        .where('locked', isEqualTo: true)
        .get();

    if (snap.docs.isEmpty) return;

    // Sort by submission time to determine streak order
    final preds = snap.docs.map((d) => d.data()).toList()
      ..sort((a, b) {
        final ta = (a['submittedAt'] as Timestamp).millisecondsSinceEpoch;
        final tb = (b['submittedAt'] as Timestamp).millisecondsSinceEpoch;
        return ta.compareTo(tb);
      });

    final userSnap = await _db.collection('users').doc(userId).get();
    final currentBadges =
        List<String>.from(userSnap.data()?['badgeIds'] as List? ?? []);

    final toAward = <String>[];

    // Sniper: any exact scoreline (5 pts)
    if (!currentBadges.contains(sniper)) {
      if (preds.any((p) => (p['pointsEarned'] as int? ?? 0) == 5)) {
        toAward.add(sniper);
      }
    }

    // On Fire: 5+ consecutive predictions with points > 0
    if (!currentBadges.contains(onFire)) {
      int streak = 0;
      for (final p in preds) {
        if ((p['pointsEarned'] as int? ?? 0) > 0) {
          streak++;
          if (streak >= 5) {
            toAward.add(onFire);
            break;
          }
        } else {
          streak = 0;
        }
      }
    }

    if (toAward.isNotEmpty) {
      await _db.collection('users').doc(userId).update({
        'badgeIds': FieldValue.arrayUnion(toAward),
      });
    }
  }
}
