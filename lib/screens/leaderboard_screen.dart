import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/user_avatar.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().userModel!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Leaderboard',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.white38,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'All Time'),
            Tab(text: 'This Week'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LeaderboardTab(
              sortField: 'totalPoints', currentUserId: currentUserId),
          _LeaderboardTab(
              sortField: 'weeklyPoints', currentUserId: currentUserId),
        ],
      ),
    );
  }
}

// ── Tab body ──────────────────────────────────────────────────────────────────

class _LeaderboardTab extends StatefulWidget {
  final String sortField;
  final String currentUserId;

  const _LeaderboardTab({required this.sortField, required this.currentUserId});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  int _limit = 20;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Reads /publicProfiles rather than /users: the latter is readable only
      // by its owner, so this query was rejected outright and the leaderboard
      // never rendered a single row.
      stream: FirebaseFirestore.instance
          .collection('publicProfiles')
          .orderBy(widget.sortField, descending: true)
          .limit(_limit)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.accent));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center),
          );
        }

        final users = (snapshot.data?.docs ?? [])
            .map((d) => UserModel.fromPublicProfile(d.data(), d.id))
            .toList();

        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 56, color: Colors.white12),
                SizedBox(height: 12),
                Text('No players yet',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        final hasMore = users.length == _limit;

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: users.length + (hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            if (i == users.length) {
              return _LoadMoreButton(onTap: () => setState(() => _limit += 20));
            }
            return _RankCard(
              rank: i + 1,
              user: users[i],
              isCurrentUser: users[i].uid == widget.currentUserId,
              sortField: widget.sortField,
            );
          },
        );
      },
    );
  }
}

// ── Rank card ─────────────────────────────────────────────────────────────────

class _RankCard extends StatelessWidget {
  final int rank;
  final UserModel user;
  final bool isCurrentUser;
  final String sortField;

  const _RankCard({
    required this.rank,
    required this.user,
    required this.isCurrentUser,
    required this.sortField,
  });

  @override
  Widget build(BuildContext context) {
    final pts =
        sortField == 'weeklyPoints' ? user.weeklyPoints : user.totalPoints;
    final rankCol = AppColors.forRank(rank);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.gradientStart : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.accent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 32,
            child: rank <= 3
                ? Icon(Icons.emoji_events, color: rankCol, size: 22)
                : Text(
                    '#$rank',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 10),
          // Avatar
          UserAvatar(photoUrl: user.photoUrl, displayName: user.displayName),
          const SizedBox(width: 12),
          // Name + accuracy
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (user.isPremium)
                      const Icon(Icons.star, color: AppColors.gold, size: 12),
                    if (user.isPremium) const SizedBox(width: 4),
                    Text(
                      isCurrentUser
                          ? '${user.displayName} (you)'
                          : user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.white70,
                        fontWeight:
                            isCurrentUser ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${user.accuracy.toStringAsFixed(1)}% accuracy',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          // Points
          Text(
            '$pts',
            style: TextStyle(
                color: rankCol, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 4),
          const Text('pts',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

// ── Load more button ──────────────────────────────────────────────────────────

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.expand_more, color: AppColors.accent, size: 18),
        label:
            const Text('Load more', style: TextStyle(color: AppColors.accent)),
      ),
    );
  }
}
