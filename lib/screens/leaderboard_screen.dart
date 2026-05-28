import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

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
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Leaderboard',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF4CAF50),
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

  const _LeaderboardTab(
      {required this.sortField, required this.currentUserId});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  int _limit = 20;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy(widget.sortField, descending: true)
          .limit(_limit)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center),
          );
        }

        final users = (snapshot.data?.docs ?? [])
            .map((d) => UserModel.fromFirestore(d.data(), d.id))
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
              return _LoadMoreButton(
                  onTap: () => setState(() => _limit += 20));
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
    final rankCol = _rankColor(rank);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? const Color(0xFF1E3A5F)
            : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF4CAF50).withOpacity(0.45)
              : Colors.white.withOpacity(0.05),
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
          _MiniAvatar(
              photoUrl: user.photoUrl, displayName: user.displayName),
          const SizedBox(width: 12),
          // Name + accuracy
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '${user.displayName} (you)' : user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.white70,
                    fontWeight: isCurrentUser
                        ? FontWeight.bold
                        : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${user.accuracy.toStringAsFixed(1)}% accuracy',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
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

  Color _rankColor(int r) {
    if (r == 1) return const Color(0xFFFFD700);
    if (r == 2) return const Color(0xFFBDBDBD);
    if (r == 3) return const Color(0xFFCD7F32);
    return Colors.white70;
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final String photoUrl;
  final String displayName;

  const _MiniAvatar({required this.photoUrl, required this.displayName});

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFF4CAF50),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _initials(),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF4CAF50),
      child: _initials(),
    );
  }

  Widget _initials() => Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
}

// ── Load more button ──────────────────────────────────────────────────────────

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.expand_more,
            color: Color(0xFF4CAF50), size: 18),
        label: const Text('Load more',
            style: TextStyle(color: Color(0xFF4CAF50))),
      ),
    );
  }
}
