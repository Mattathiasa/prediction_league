import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fixture_model.dart';
import '../models/prediction_model.dart';
import '../providers/prediction_provider.dart';
import '../services/fixture_service.dart';
import '../services/scoring_service.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Results',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: StreamBuilder<List<FixtureModel>>(
        stream: FixtureService().finishedFixtures(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
          }

          final fixtures = snapshot.data ?? [];

          if (fixtures.isEmpty) {
            return const _EmptyResults();
          }

          // Watch predictions — already loaded by PredictionProvider stream
          final predProvider = context.watch<PredictionProvider>();

          // Compute a quick summary from loaded prediction data
          final scored = predProvider.predictions.values
              .where((p) => p.locked)
              .toList();
          final totalEarned =
              scored.fold<int>(0, (sum, p) => sum + p.pointsEarned);

          return Column(
            children: [
              _SummaryBar(
                  finishedCount: fixtures.length,
                  pointsEarned: totalEarned,
                  predictedCount: scored.length),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: fixtures.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final fixture = fixtures[i];
                    final prediction = predProvider
                        .predictionForFixture(fixture.fixtureId);
                    return _ResultCard(
                        fixture: fixture, prediction: prediction);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int finishedCount;
  final int pointsEarned;
  final int predictedCount;

  const _SummaryBar({
    required this.finishedCount,
    required this.pointsEarned,
    required this.predictedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          _SummaryStat(
              label: 'Matches', value: '$finishedCount'),
          _divider(),
          _SummaryStat(
              label: 'Predicted', value: '$predictedCount'),
          _divider(),
          _SummaryStat(
              label: 'Points earned',
              value: '$pointsEarned',
              highlight: true),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 32, color: Colors.white.withOpacity(0.1));
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryStat(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: highlight
                    ? const Color(0xFF4CAF50)
                    : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final FixtureModel fixture;
  final PredictionModel? prediction;

  const _ResultCard({required this.fixture, this.prediction});

  @override
  Widget build(BuildContext context) {
    final pts = prediction?.pointsEarned ?? -1;
    final color = ScoringService.pointsColor(pts);
    final label = ScoringService.pointsLabel(pts);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          // Match + result row
          Row(
            children: [
              Expanded(
                child: Text(fixture.homeTeam,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    maxLines: 2),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2137),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${fixture.homeScore ?? '?'} – ${fixture.awayScore ?? '?'}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              Expanded(
                child: Text(fixture.awayTeam,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    maxLines: 2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Prediction + points row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // My prediction
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: Colors.white38),
                  const SizedBox(width: 5),
                  Text(
                    prediction != null
                        ? 'You: ${prediction!.homeGuess}–${prediction!.awayGuess}'
                        : 'No prediction',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              // Points badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: color.withOpacity(0.45), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pts >= 0 ? '+$pts' : '$pts',
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 5),
                    Text(label,
                        style: TextStyle(
                            color: color.withOpacity(0.8),
                            fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 64, color: Colors.white12),
          SizedBox(height: 16),
          Text('No results yet',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Results appear here once matches finish',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}
