import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'admin_screen.dart';
import 'fixture_list_screen.dart';
import 'leaderboard_screen.dart';
import 'my_league_screen.dart';
import 'profile_screen.dart';
import 'results_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.userModel!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        title: const Text(
          'Prediction League',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1A1A2E),
            onSelected: (value) async {
              if (value == 'admin') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()));
              } else if (value == 'signout') {
                final confirmed = await _confirmSignOut(context);
                if (confirmed && context.mounted) await auth.signOut();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'admin',
                child: Row(children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      color: Colors.white54, size: 18),
                  SizedBox(width: 10),
                  Text('Admin', style: TextStyle(color: Colors.white70)),
                ]),
              ),
              const PopupMenuItem(
                value: 'signout',
                child: Row(children: [
                  Icon(Icons.logout, color: Colors.white54, size: 18),
                  SizedBox(width: 10),
                  Text('Sign out', style: TextStyle(color: Colors.white70)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileCard(user: user),
            const SizedBox(height: 28),
            const Text(
              'Your Stats',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _StatsGrid(user: user),
            const SizedBox(height: 28),
            _FixturesNavCard(),
            const SizedBox(height: 12),
            _ResultsNavCard(),
            const SizedBox(height: 12),
            _LeaderboardNavCard(),
            const SizedBox(height: 12),
            _MyLeagueNavCard(),
            const SizedBox(height: 12),
            _ProfileNavCard(),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmSignOut(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text('Sign out?', style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _Avatar(photoUrl: user.photoUrl, displayName: user.displayName),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  user.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF4CAF50), width: 0.5),
                  ),
                  child: Text(
                    '${user.totalPoints} pts total',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String photoUrl;
  final String displayName;
  const _Avatar({required this.photoUrl, required this.displayName});

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 34,
        backgroundColor: const Color(0xFF4CAF50),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            width: 68,
            height: 68,
            fit: BoxFit.cover,
            placeholder: (_, __) => const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
            errorWidget: (_, __, ___) => _initialsWidget(displayName),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 34,
      backgroundColor: const Color(0xFF4CAF50),
      child: _initialsWidget(displayName),
    );
  }

  Widget _initialsWidget(String name) {
    return Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final UserModel user;
  const _StatsGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.35,
      children: [
        _StatCard(
          label: 'Total Points',
          value: '${user.totalPoints}',
          icon: Icons.star_rounded,
          color: const Color(0xFFFFD700),
        ),
        _StatCard(
          label: 'This Week',
          value: '${user.weeklyPoints}',
          icon: Icons.calendar_today_rounded,
          color: const Color(0xFF29B6F6),
        ),
        _StatCard(
          label: 'Streak',
          value: '${user.streak}d',
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFFF7043),
        ),
        _StatCard(
          label: 'Accuracy',
          value: '${user.accuracy.toStringAsFixed(1)}%',
          icon: Icons.track_changes_rounded,
          color: const Color(0xFF4CAF50),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 26),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FixturesNavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FixtureListScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF4CAF50).withOpacity(0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.sports_soccer, color: Color(0xFF4CAF50), size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premier League Fixtures',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap to view matches and submit predictions',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _ResultsNavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResultsScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFFFD700).withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.emoji_events_outlined,
                color: Color(0xFFFFD700), size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Results & Points',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'See finished matches and your score',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardNavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF29B6F6).withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.leaderboard_outlined, color: Color(0xFF29B6F6), size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Leaderboard',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 2),
                  Text('All-time and weekly rankings',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _MyLeagueNavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyLeagueScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF7043).withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFFF7043), size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My League',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  SizedBox(height: 2),
                  Text('Private leagues with friends',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _ProfileNavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBDBDBD).withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.person_outline, color: Color(0xFFBDBDBD), size: 28),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Profile',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  SizedBox(height: 2),
                  Text('Stats, badges, and streaks',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
