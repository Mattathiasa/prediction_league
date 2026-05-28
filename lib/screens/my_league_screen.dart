import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/league_model.dart';
import '../models/user_model.dart';
import '../providers/league_provider.dart';
import '../services/auth_service.dart';
import 'create_league_screen.dart';
import 'join_league_screen.dart';

class MyLeagueScreen extends StatefulWidget {
  const MyLeagueScreen({super.key});

  @override
  State<MyLeagueScreen> createState() => _MyLeagueScreenState();
}

class _MyLeagueScreenState extends State<MyLeagueScreen> {
  LeagueModel? _selected;

  @override
  Widget build(BuildContext context) {
    final leagueProvider = context.watch<LeagueProvider>();
    final currentUser = context.read<AuthService>().userModel!;
    final leagues = leagueProvider.leagues;

    // Keep selection valid
    final effective = (_selected != null &&
            leagues.any((l) => l.leagueId == _selected!.leagueId))
        ? _selected!
        : (leagues.isNotEmpty ? leagues.first : null);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('My League',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          if (effective != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xFF1A1A2E),
              onSelected: (v) {
                if (v == 'join') {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const JoinLeagueScreen()));
                } else if (v == 'create') {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CreateLeagueScreen()));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'join',
                  child: Row(children: [
                    Icon(Icons.group_add, color: Colors.white54, size: 18),
                    SizedBox(width: 10),
                    Text('Join another league',
                        style: TextStyle(color: Colors.white70)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'create',
                  child: Row(children: [
                    Icon(Icons.add_circle_outline,
                        color: Colors.white54, size: 18),
                    SizedBox(width: 10),
                    Text('Create new league',
                        style: TextStyle(color: Colors.white70)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: leagueProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : effective == null
              ? _EmptyLeague(currentUserId: currentUser.uid)
              : Column(
                  children: [
                    // League picker (only shown if in multiple)
                    if (leagues.length > 1)
                      _LeaguePicker(
                        leagues: leagues,
                        selected: effective,
                        onSelect: (l) => setState(() => _selected = l),
                      ),
                    // League info header
                    _LeagueHeader(league: effective),
                    // Standings
                    Expanded(
                      child: _LeagueStandings(
                        key: ValueKey(effective.leagueId),
                        league: effective,
                        currentUser: currentUser,
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyLeague extends StatelessWidget {
  final String currentUserId;
  const _EmptyLeague({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined, size: 64, color: Colors.white12),
            const SizedBox(height: 16),
            const Text("You're not in any leagues",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            const SizedBox(height: 8),
            const Text(
              'Create a private league and invite friends,\nor join one with an invite code.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateLeagueScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create a League',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const JoinLeagueScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                  side:
                      const BorderSide(color: Color(0xFF4CAF50), width: 0.8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.group_add),
                label: const Text('Join with a Code',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── League picker dropdown ────────────────────────────────────────────────────

class _LeaguePicker extends StatelessWidget {
  final List<LeagueModel> leagues;
  final LeagueModel selected;
  final void Function(LeagueModel) onSelect;

  const _LeaguePicker(
      {required this.leagues,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LeagueModel>(
          value: selected,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A2E),
          iconEnabledColor: Colors.white38,
          items: leagues
              .map((l) => DropdownMenuItem(
                    value: l,
                    child: Text(l.name,
                        style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
          onChanged: (l) {
            if (l != null) onSelect(l);
          },
        ),
      ),
    );
  }
}

// ── League info header ────────────────────────────────────────────────────────

class _LeagueHeader extends StatelessWidget {
  final LeagueModel league;
  const _LeagueHeader({required this.league});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined,
              color: Color(0xFF4CAF50), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(league.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 2),
                Text('${league.memberIds.length} members',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          // Copy invite code
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: league.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite code copied!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    league.inviteCode,
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.copy,
                      size: 13, color: Color(0xFF4CAF50)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── League standings ──────────────────────────────────────────────────────────

class _LeagueStandings extends StatelessWidget {
  final LeagueModel league;
  final UserModel currentUser;

  const _LeagueStandings({
    super.key,
    required this.league,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: context
          .read<LeagueProvider>()
          .getLeagueMembers(league.memberIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white54)));
        }

        final members = snapshot.data ?? [];

        return Column(
          children: [
            // Column headers
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(
                children: [
                  SizedBox(width: 32),
                  SizedBox(width: 42),
                  Expanded(
                      child: Text('Player',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11))),
                  SizedBox(
                    width: 52,
                    child: Text('Pts',
                        textAlign: TextAlign.right,
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text('vs You',
                        textAlign: TextAlign.right,
                        style:
                            TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _MemberRow(
                  rank: i + 1,
                  member: members[i],
                  currentUser: currentUser,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  final int rank;
  final UserModel member;
  final UserModel currentUser;

  const _MemberRow(
      {required this.rank,
      required this.member,
      required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final isMe = member.uid == currentUser.uid;
    final diff = isMe ? 0 : currentUser.totalPoints - member.totalPoints;
    final diffText = isMe
        ? '—'
        : diff == 0
            ? '='
            : diff > 0
                ? '+$diff'
                : '$diff';
    final diffColor = isMe
        ? Colors.white38
        : diff > 0
            ? const Color(0xFF4CAF50)
            : diff < 0
                ? const Color(0xFFFF7043)
                : Colors.white38;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF1E3A5F) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? const Color(0xFF4CAF50).withOpacity(0.4)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 24,
            child: rank <= 3
                ? Icon(Icons.emoji_events,
                    color: _rankColor(rank), size: 18)
                : Text('#$rank',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          // Avatar
          _TinyAvatar(
              photoUrl: member.photoUrl, displayName: member.displayName),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              isMe ? '${member.displayName} (you)' : member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.white70,
                fontWeight:
                    isMe ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
          // Points
          SizedBox(
            width: 52,
            child: Text('${member.totalPoints}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          // vs You
          SizedBox(
            width: 52,
            child: Text(diffText,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: diffColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int r) {
    if (r == 1) return const Color(0xFFFFD700);
    if (r == 2) return const Color(0xFFBDBDBD);
    return const Color(0xFFCD7F32);
  }
}

class _TinyAvatar extends StatelessWidget {
  final String photoUrl;
  final String displayName;
  const _TinyAvatar({required this.photoUrl, required this.displayName});

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF4CAF50),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _initials(),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF4CAF50),
      child: _initials(),
    );
  }

  Widget _initials() => Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
}
