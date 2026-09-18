import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/prediction_provider.dart';
import '../services/prediction_service.dart';
import '../services/scoring_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthService>().userModel!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Prediction History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<List<HistoryEntry>>(
        stream: context.read<PredictionProvider>().historyStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white38),
                textAlign: TextAlign.center,
              ),
            );
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return const _EmptyHistory();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryHeader(entries: entries),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _HistoryCard(entry: entries[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final List<HistoryEntry> entries;
  const _SummaryHeader({required this.entries});

  @override
  Widget build(BuildContext context) {
    final totalPoints = entries.fold<int>(0, (sum, e) => sum + e.prediction.pointsEarned);
    final correctResults = entries
        .where((e) => ScoringService.calculatePoints(
              homeGuess: e.prediction.homeGuess,
              awayGuess: e.prediction.awayGuess,
              homeScore: e.fixture?.homeScore ?? 0,
              awayScore: e.fixture?.awayScore ?? 0,
            ) > 0)
        .length;
    final exactScores = entries
        .where((e) => e.prediction.pointsEarned == 5)
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'Total Pts', value: '$totalPoints',
              color: const Color(0xFFFFD700), icon: Icons.star_rounded),
          _StatItem(label: 'Correct Results', value: '$correctResults/${entries.length}',
              color: const Color(0xFF4CAF50), icon: Icons.track_changes_rounded),
          _StatItem(label: 'Exact Scores', value: '$exactScores',
              color: const Color(0xFF29B6F6), icon: Icons.emoji_events),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatItem({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final fixture = entry.fixture;
    final prediction = entry.prediction;
    final pts = prediction.pointsEarned;
    final label = ScoringService.pointsLabel(pts);
    final color = ScoringService.pointsColor(pts);

    if (fixture == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${prediction.homeGuess} — ${prediction.awayGuess}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Fixture data unavailable',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            Text(
              '$label ($pts pts)',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final local = fixture.kickoff.toLocal();
    final dateStr = '${local.day}/${local.month}/${local.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // Teams + result row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                  child: Text(fixture.homeTeam,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13))),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2137),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${fixture.homeScore} — ${fixture.awayScore}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              Expanded(
                  child: Text(fixture.awayTeam,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13))),
            ],
          ),
          const SizedBox(height: 12),
          // Prediction row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    '${prediction.homeGuess} — ${prediction.awayGuess}',
                    style: const TextStyle(
                        color: Color(0xFF29B6F6),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const Text('Your prediction',
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
              Column(
                children: [
                  Text(
                    pts >= 0 ? '+$pts' : '$pts',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  Text(label,
                      style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
                ],
              ),
              Text(dateStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.white12),
          SizedBox(height: 16),
          Text('No prediction history yet',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Your scored predictions will appear here',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}
