import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fixture_model.dart';
import '../../services/auth_service.dart';
import '../../services/fixture_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/step_button.dart';

class AdminFixtureList extends StatelessWidget {
  final FixtureService service;

  const AdminFixtureList({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FixtureModel>>(
      stream: service.adminFixtures(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        final fixtures = snapshot.data ?? [];

        if (fixtures.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.white12,
                ),
                SizedBox(height: 16),
                Text(
                  'All results entered',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'No upcoming or live fixtures remaining',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: fixtures.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => AdminFixtureCard(
            fixture: fixtures[i],
            onEnterResult: () => _showResultSheet(context, fixtures[i]),
          ),
        );
      },
    );
  }

  Future<void> _showResultSheet(BuildContext context, FixtureModel fixture) {
    final currentUserId =
        Provider.of<AuthService>(context, listen: false).userModel?.uid;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ResultEntrySheet(
        fixture: fixture,
        fixtureService: service,
        currentUserId: currentUserId,
      ),
    );
  }
}

class AdminFixtureCard extends StatelessWidget {
  final FixtureModel fixture;
  final VoidCallback onEnterResult;

  const AdminFixtureCard({
    super.key,
    required this.fixture,
    required this.onEnterResult,
  });

  @override
  Widget build(BuildContext context) {
    final local = fixture.kickoff.toLocal();
    final dateStr =
        '${local.day}/${local.month}  ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fixture.homeTeam}  vs  ${fixture.awayTeam}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onEnterResult,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Enter Result',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class ResultEntrySheet extends StatefulWidget {
  final FixtureModel fixture;
  final FixtureService fixtureService;
  final String? currentUserId;

  const ResultEntrySheet({
    super.key,
    required this.fixture,
    required this.fixtureService,
    this.currentUserId,
  });

  @override
  State<ResultEntrySheet> createState() => ResultEntrySheetState();
}

class ResultEntrySheetState extends State<ResultEntrySheet> {
  int _home = 0;
  int _away = 0;
  bool _submitting = false;

  void _change(bool isHome, int delta) {
    setState(() {
      if (isHome) {
        _home = (_home + delta).clamp(0, 20);
      } else {
        _away = (_away + delta).clamp(0, 20);
      }
    });
  }

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:
            const Text('Confirm Result', style: TextStyle(color: Colors.white)),
        content: Text(
          '${widget.fixture.homeTeam} $_home – $_away ${widget.fixture.awayTeam}\n\n'
          'This will score all predictions and update user points.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);

    try {
      final userPoints = await widget.fixtureService.scoreFixtureResults(
        fixtureId: widget.fixture.fixtureId,
        homeScore: _home,
        awayScore: _away,
        currentUserId: widget.currentUserId,
      );

      // On-device notification with the result + this user's points
      await NotificationService.showResultNotification(
        homeTeam: widget.fixture.homeTeam,
        awayTeam: widget.fixture.awayTeam,
        homeScore: _home,
        awayScore: _away,
        pointsEarned: userPoints,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Result submitted — predictions scored!'),
          backgroundColor: AppColors.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            '${widget.fixture.homeTeam} vs ${widget.fixture.awayTeam}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Final Score',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScoreColumn(
                label: widget.fixture.homeTeam,
                value: _home,
                onChange: (d) => _change(true, d),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '–',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ScoreColumn(
                label: widget.fixture.awayTeam,
                value: _away,
                onChange: (d) => _change(false, d),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Submit Result',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScoreColumn extends StatelessWidget {
  final String label;
  final int value;
  final void Function(int) onChange;

  const ScoreColumn({
    super.key,
    required this.label,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        StepButton(icon: Icons.add, onPressed: () => onChange(1)),
        const SizedBox(height: 8),
        SizedBox(
          width: 56,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        StepButton(icon: Icons.remove, onPressed: () => onChange(-1)),
      ],
    );
  }
}

class ResetWeeklyPointsBar extends StatelessWidget {
  final bool resetting;
  final VoidCallback onReset;

  const ResetWeeklyPointsBar({
    super.key,
    required this.resetting,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.restart_alt, color: Colors.white38, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset Weekly Points',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Sets all weeklyPoints to 0 — do this each Monday',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: resetting ? null : onReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: resetting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Reset',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
