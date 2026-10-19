import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/nav_card.dart';
import '../widgets/user_avatar.dart';
import 'admin_screen.dart';
import 'fixture_list_screen.dart';
import 'history_screen.dart';
import 'leaderboard_screen.dart';
import 'my_league_screen.dart';
import 'paywall_screen.dart';
import 'profile_screen.dart';
import 'results_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.userModel!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
            color: AppColors.surface,
            onSelected: (value) async {
              if (value == 'admin') {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const AdminScreen()),
                );
              } else if (value == 'premium') {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PaywallScreen(),
                  ),
                );
              } else if (value == 'signout') {
                final confirmed = await _confirmSignOut(context);
                if (confirmed && context.mounted) await auth.signOut();
              }
            },
            itemBuilder: (_) {
              final items = <PopupMenuEntry<String>>[];
              if (auth.isAdmin) {
                items.add(
                  const PopupMenuItem(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings_outlined,
                          color: Colors.white54,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text('Admin', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                );
              }
              items.addAll([
                const PopupMenuItem(
                  value: 'premium',
                  child: Row(
                    children: [
                      Icon(Icons.star_outline, color: Colors.white54, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Go Premium',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'signout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.white54, size: 18),
                      SizedBox(width: 10),
                      Text('Sign out', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ]);
              return items;
            },
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
            for (final dest in _destinations) ...[
              NavCard(
                icon: dest.icon,
                iconColor: dest.color,
                title: dest.title,
                subtitle: dest.subtitle,
                builder: dest.builder,
              ),
              const SizedBox(height: 12),
            ],
            Consumer<SubscriptionService>(
              builder: (context, sub, _) => ConditionalBannerAd(
                isPremium: sub.isPremium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmSignOut(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title:
                const Text('Sign out?', style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
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
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          UserAvatar(
            radius: 34,
            photoUrl: user.photoUrl,
            displayName: user.displayName,
          ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accent, width: 0.5),
                  ),
                  child: Text(
                    '${user.totalPoints} pts total',
                    style: const TextStyle(
                      color: AppColors.accent,
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
          color: AppColors.gold,
        ),
        _StatCard(
          label: 'This Week',
          value: '${user.weeklyPoints}',
          icon: Icons.calendar_today_rounded,
          color: AppColors.info,
        ),
        _StatCard(
          label: 'Streak',
          value: '${user.streak}d',
          icon: Icons.local_fire_department_rounded,
          color: AppColors.live,
        ),
        _StatCard(
          label: 'Accuracy',
          value: '${user.accuracy.toStringAsFixed(1)}%',
          icon: Icons.track_changes_rounded,
          color: AppColors.accent,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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

/// The home screen's navigation targets, in display order.
class _Destination {
  const _Destination({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

const _destinations = <_Destination>[
  _Destination(
    icon: Icons.sports_soccer,
    color: AppColors.accent,
    title: 'Premier League Fixtures',
    subtitle: 'Tap to view matches and submit predictions',
    builder: _fixtures,
  ),
  _Destination(
    icon: Icons.emoji_events_outlined,
    color: AppColors.gold,
    title: 'Results & Points',
    subtitle: 'See finished matches and your score',
    builder: _results,
  ),
  _Destination(
    icon: Icons.history,
    color: AppColors.gold,
    title: 'Prediction History',
    subtitle: 'Review past predictions and points',
    builder: _history,
  ),
  _Destination(
    icon: Icons.leaderboard_outlined,
    color: AppColors.info,
    title: 'Leaderboard',
    subtitle: 'All-time and weekly rankings',
    builder: _leaderboard,
  ),
  _Destination(
    icon: Icons.shield_outlined,
    color: AppColors.live,
    title: 'My League',
    subtitle: 'Private leagues with friends',
    builder: _myLeague,
  ),
  _Destination(
    icon: Icons.person_outline,
    color: AppColors.silver,
    title: 'My Profile',
    subtitle: 'Stats, badges, and streaks',
    builder: _profile,
  ),
];

// Top-level functions so the list above can stay `const`.
Widget _fixtures(BuildContext _) => const FixtureListScreen();
Widget _results(BuildContext _) => const ResultsScreen();
Widget _history(BuildContext _) => const HistoryScreen();
Widget _leaderboard(BuildContext _) => const LeaderboardScreen();
Widget _myLeague(BuildContext _) => const MyLeagueScreen();
Widget _profile(BuildContext _) => const ProfileScreen();
