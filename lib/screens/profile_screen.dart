import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().userModel!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Profile',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: 24),
            _StatsRow(user: user),
            const SizedBox(height: 28),
            _BadgesSection(user: user),
          ],
        ),
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar
        user.photoUrl.isNotEmpty
            ? CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFF4CAF50),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: user.photoUrl,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _initials(user.displayName),
                  ),
                ),
              )
            : CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFF4CAF50),
                child: _initials(user.displayName),
              ),
        const SizedBox(height: 14),
        // Name
        Text(
          user.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        // Points badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
          ),
          child: Text(
            '${user.totalPoints} pts total',
            style: const TextStyle(
              color: Color(0xFF4CAF50),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _initials(String name) => Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
      );
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final UserModel user;
  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
              label: 'This Week',
              value: '${user.weeklyPoints}',
              icon: Icons.calendar_today_rounded,
              color: const Color(0xFF29B6F6)),
          _divider(),
          _Stat(
              label: 'Accuracy',
              value: '${user.accuracy.toStringAsFixed(1)}%',
              icon: Icons.track_changes_rounded,
              color: const Color(0xFF4CAF50)),
          _divider(),
          _Stat(
              label: 'Best Streak',
              value: '${user.bestStreak}',
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFFF7043)),
          _divider(),
          _Stat(
              label: 'Streak',
              value: '${user.streak}',
              icon: Icons.bolt_rounded,
              color: const Color(0xFFFFD700)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.08));
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Stat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

// ── Badges section ────────────────────────────────────────────────────────────

class _BadgesSection extends StatelessWidget {
  final UserModel user;
  const _BadgesSection({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Badges',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.85,
          ),
          itemCount: BadgeService.all.length,
          itemBuilder: (context, i) {
            final badgeId = BadgeService.all[i];
            final info = BadgeService.getInfo(badgeId);
            final earned = user.badgeIds.contains(badgeId);
            return _BadgeCard(info: info, earned: earned);
          },
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeInfo info;
  final bool earned;

  const _BadgeCard({required this.info, required this.earned});

  @override
  Widget build(BuildContext context) {
    final color = earned ? info.color : Colors.white12;
    final textColor = earned ? Colors.white : Colors.white24;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: earned ? info.color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(info.icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            info.name,
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            earned ? info.description : '???',
            style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
