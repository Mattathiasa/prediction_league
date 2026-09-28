import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league_model.dart';
import '../providers/league_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'create_league_screen.dart';
import 'join_league_screen.dart';
import 'my_league/my_league_widgets.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My League',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (effective != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: AppColors.surface,
              onSelected: (v) {
                if (v == 'join') {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const JoinLeagueScreen(),
                    ),
                  );
                } else if (v == 'create') {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateLeagueScreen(),
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'join',
                  child: Row(
                    children: [
                      Icon(Icons.group_add, color: Colors.white54, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Join another league',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'create',
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.white54,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Create new league',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: leagueProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : effective == null
              ? EmptyLeague(currentUserId: currentUser.uid)
              : Column(
                  children: [
                    // League picker (only shown if in multiple)
                    if (leagues.length > 1)
                      LeaguePicker(
                        leagues: leagues,
                        selected: effective,
                        onSelect: (l) => setState(() => _selected = l),
                      ),
                    // League info header
                    LeagueHeader(league: effective),
                    // Weekly matchups
                    WeeklyMatchups(leagueId: effective.leagueId),
                    // Standings
                    Expanded(
                      child: LeagueStandings(
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

// ── League picker dropdown ────────────────────────────────────────────────────

// ── League info header ────────────────────────────────────────────────────────

// ── Weekly matchups ─────────────────────────────────────────────────────────────

// ── League standings ──────────────────────────────────────────────────────────
