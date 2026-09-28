import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/league_model.dart';
import '../../models/matchup_model.dart';
import '../../models/user_model.dart';
import '../../providers/league_provider.dart';
import '../../services/league_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../create_league_screen.dart';
import '../join_league_screen.dart';

class EmptyLeague extends StatelessWidget {
  final String currentUserId;
  const EmptyLeague({super.key, required this.currentUserId});

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
            const Text(
              "You're not in any leagues",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
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
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateLeagueScreen(),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text(
                  'Create a League',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const JoinLeagueScreen(),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent, width: 0.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.group_add),
                label: const Text(
                  'Join with a Code',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LeaguePicker extends StatelessWidget {
  final List<LeagueModel> leagues;
  final LeagueModel selected;
  final void Function(LeagueModel) onSelect;

  const LeaguePicker({
    super.key,
    required this.leagues,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LeagueModel>(
          value: selected,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          iconEnabledColor: Colors.white38,
          items: leagues
              .map(
                (l) => DropdownMenuItem(
                  value: l,
                  child: Text(
                    l.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
              .toList(),
          onChanged: (l) {
            if (l != null) onSelect(l);
          },
        ),
      ),
    );
  }
}

class LeagueHeader extends StatelessWidget {
  final LeagueModel league;
  const LeagueHeader({super.key, required this.league});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.accent, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  league.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${league.memberIds.length} members',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          // Copy invite code
          GestureDetector(
            onTap: () {
              unawaited(
                Clipboard.setData(ClipboardData(text: league.inviteCode)),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite code copied!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    league.inviteCode,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.copy, size: 13, color: AppColors.accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyMatchups extends StatefulWidget {
  final String leagueId;
  const WeeklyMatchups({super.key, required this.leagueId});

  @override
  State<WeeklyMatchups> createState() => WeeklyMatchupsState();
}

class WeeklyMatchupsState extends State<WeeklyMatchups> {
  // Resolved once per league. Calling this inside build() re-ran a league read
  // plus a chunked fan-out over every member on each rebuild — and the parent
  // rebuilds whenever any of four providers notifies.
  late Future<List<LeagueMatchup>> _matchups = _load();

  Future<List<LeagueMatchup>> _load() =>
      LeagueService().getWeeklyMatchups(widget.leagueId);

  @override
  void didUpdateWidget(WeeklyMatchups oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leagueId != widget.leagueId) {
      _matchups = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LeagueMatchup>>(
      future: _matchups,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final matchups = snapshot.data ?? [];
        if (matchups.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();
        final weekNum = _weekOfYear(now);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'GW $weekNum Matchups',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: matchups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => MatchupCard(matchup: matchups[i]),
            ),
          ],
        );
      },
    );
  }

  int _weekOfYear(DateTime date) {
    final start = DateTime(date.year);
    final firstMonday = (8 - start.weekday) % 7;
    final firstWeekStart = start.add(Duration(days: firstMonday));
    if (date.isBefore(firstWeekStart)) return 52;
    return ((date.difference(firstWeekStart).inDays) / 7).floor() + 1;
  }
}

class MatchupCard extends StatelessWidget {
  final LeagueMatchup matchup;
  const MatchupCard({super.key, required this.matchup});

  @override
  Widget build(BuildContext context) {
    if (matchup.isBye) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            UserAvatar(
              radius: 16,
              photoUrl: matchup.home.photoUrl,
              displayName: matchup.home.displayName,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${matchup.home.displayName} (BYE)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.45),
                  width: 0.5,
                ),
              ),
              child: const Text(
                'WON',
                style: TextStyle(color: AppColors.gold, fontSize: 10),
              ),
            ),
          ],
        ),
      );
    }

    final home = matchup.home;
    final away = matchup.away!;
    final homeColor = matchup.homeWon
        ? AppColors.accent
        : matchup.isDraw
            ? Colors.white70
            : AppColors.live;
    final awayColor = matchup.awayWon
        ? AppColors.accent
        : matchup.isDraw
            ? Colors.white70
            : AppColors.live;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Home
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${home.weeklyPoints}',
                  style: TextStyle(
                    color: homeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  home.displayName,
                  style: TextStyle(
                    color: homeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 6),
                UserAvatar(
                  radius: 16,
                  photoUrl: home.photoUrl,
                  displayName: home.displayName,
                ),
              ],
            ),
          ),
          // VS divider
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: const Text(
              'VS',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ),
          // Away
          Expanded(
            child: Row(
              children: [
                UserAvatar(
                  radius: 16,
                  photoUrl: away.photoUrl,
                  displayName: away.displayName,
                ),
                const SizedBox(width: 6),
                Text(
                  away.displayName,
                  style: TextStyle(
                    color: awayColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 6),
                Text(
                  '${away.weeklyPoints}',
                  style: TextStyle(
                    color: awayColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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

class LeagueStandings extends StatefulWidget {
  final LeagueModel league;
  final UserModel currentUser;

  const LeagueStandings({
    super.key,
    required this.league,
    required this.currentUser,
  });

  @override
  State<LeagueStandings> createState() => LeagueStandingsState();
}

class LeagueStandingsState extends State<LeagueStandings> {
  // Same reasoning as WeeklyMatchups: up to twenty profile reads, previously
  // re-issued on every rebuild.
  late Future<List<UserModel>> _members = _load();

  Future<List<UserModel>> _load() =>
      context.read<LeagueProvider>().getLeagueMembers(widget.league.memberIds);

  @override
  void didUpdateWidget(LeagueStandings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.league.memberIds, widget.league.memberIds)) {
      _members = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserModel>>(
      future: _members,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white54),
            ),
          );
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
                    child: Text(
                      'Player',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      'Pts',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      'vs You',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => MemberRow(
                  rank: i + 1,
                  member: members[i],
                  currentUser: widget.currentUser,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class MemberRow extends StatelessWidget {
  final int rank;
  final UserModel member;
  final UserModel currentUser;

  const MemberRow({
    super.key,
    required this.rank,
    required this.member,
    required this.currentUser,
  });

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
            ? AppColors.accent
            : diff < 0
                ? AppColors.live
                : Colors.white38;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.gradientStart : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? AppColors.accent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 24,
            child: rank <= 3
                ? Icon(
                    Icons.emoji_events,
                    color: AppColors.forRank(rank),
                    size: 18,
                  )
                : Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Avatar
          UserAvatar(
            radius: 12,
            photoUrl: member.photoUrl,
            displayName: member.displayName,
          ),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Text(
              isMe ? '${member.displayName} (you)' : member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.white70,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
          // Points
          SizedBox(
            width: 52,
            child: Text(
              '${member.totalPoints}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          // vs You
          SizedBox(
            width: 52,
            child: Text(
              diffText,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: diffColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
