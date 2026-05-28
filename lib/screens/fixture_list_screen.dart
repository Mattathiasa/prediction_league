import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fixture_model.dart';
import '../models/prediction_model.dart';
import '../providers/fixture_provider.dart';
import '../providers/prediction_provider.dart';
import 'predict_screen.dart';

class FixtureListScreen extends StatefulWidget {
  const FixtureListScreen({super.key});

  @override
  State<FixtureListScreen> createState() => _FixtureListScreenState();
}

class _FixtureListScreenState extends State<FixtureListScreen> {
  @override
  void initState() {
    super.initState();
    // Sync from football-data.org on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FixtureProvider>().syncFixtures();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fixtureProvider = context.watch<FixtureProvider>();
    final predictionProvider = context.watch<PredictionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Fixtures',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (fixtureProvider.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Color(0xFF4CAF50), strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.white70),
              tooltip: 'Refresh from API',
              onPressed: () => fixtureProvider.syncFixtures(),
            ),
        ],
      ),
      body: Column(
        children: [
          if (fixtureProvider.syncError != null)
            _ErrorBanner(message: fixtureProvider.syncError!),
          Expanded(
            child: StreamBuilder<List<FixtureModel>>(
              stream: fixtureProvider.fixturesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  );
                }

                if (snapshot.hasError) {
                  return _FirestoreError(error: snapshot.error.toString());
                }

                final fixtures = snapshot.data ?? [];

                if (fixtures.isEmpty) {
                  return _EmptyState(
                    onRefresh: () => fixtureProvider.syncFixtures(),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFF4CAF50),
                  backgroundColor: const Color(0xFF1A1A2E),
                  onRefresh: () => fixtureProvider.syncFixtures(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: fixtures.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final fixture = fixtures[index];
                      final prediction =
                          predictionProvider.predictionForFixture(
                              fixture.fixtureId);
                      return _FixtureCard(
                        fixture: fixture,
                        prediction: prediction,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PredictScreen(fixture: fixture),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fixture card ───────────────────────────────────────────────────────────────

class _FixtureCard extends StatelessWidget {
  final FixtureModel fixture;
  final PredictionModel? prediction;
  final VoidCallback onTap;

  const _FixtureCard({
    required this.fixture,
    required this.prediction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = fixture.isLocked;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: locked
                ? Colors.white.withOpacity(0.06)
                : const Color(0xFF4CAF50).withOpacity(0.25),
          ),
        ),
        child: Column(
          children: [
            // Teams row
            Row(
              children: [
                Expanded(
                  child: Text(
                    fixture.homeTeam,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                _KickoffChip(fixture: fixture),
                Expanded(
                  child: Text(
                    fixture.awayTeam,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Status row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fixture.competition,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                Row(
                  children: [
                    if (locked)
                      const _Badge(
                          label: 'LOCKED',
                          color: Color(0xFFB71C1C))
                    else
                      const _Badge(
                          label: 'OPEN',
                          color: Color(0xFF4CAF50)),
                    if (prediction != null) ...[
                      const SizedBox(width: 6),
                      _Badge(
                        label:
                            '${prediction!.homeGuess}–${prediction!.awayGuess}',
                        color: const Color(0xFF29B6F6),
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KickoffChip extends StatelessWidget {
  final FixtureModel fixture;
  const _KickoffChip({required this.fixture});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label(),
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  String _label() {
    if (fixture.isFinished && fixture.homeScore != null) {
      return '${fixture.homeScore}–${fixture.awayScore}';
    }
    if (fixture.isLive) return 'LIVE';

    final local = fixture.kickoff.toLocal();
    final now = DateTime.now();
    final diff = local.difference(now);

    if (diff.inDays == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Tomorrow';
    return '${local.day}/${local.month}';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.45), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ── Utility widgets ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.red.shade900.withOpacity(0.85),
      child: Text(
        'Sync failed: $message',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _FirestoreError extends StatelessWidget {
  final String error;
  const _FirestoreError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            const Text('Firestore error',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'If this is your first run, open the Firestore console,\n'
              'click the link in the debug log to create the composite index\n'
              '(status ASC, kickoff ASC), then restart.',
              style: TextStyle(color: Colors.white24, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_soccer,
              size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          const Text('No upcoming fixtures',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Tap sync to load from football-data.org',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRefresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.sync),
            label: const Text('Sync Fixtures'),
          ),
        ],
      ),
    );
  }
}
