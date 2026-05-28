import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/fixture_model.dart';
import '../models/prediction_model.dart';
import '../providers/prediction_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class PredictScreen extends StatefulWidget {
  final FixtureModel fixture;
  const PredictScreen({super.key, required this.fixture});

  @override
  State<PredictScreen> createState() => _PredictScreenState();
}

class _PredictScreenState extends State<PredictScreen> {
  final _homeController = TextEditingController(text: '0');
  final _awayController = TextEditingController(text: '0');

  Timer? _countdownTimer;
  Duration _timeToLock = Duration.zero;
  PredictionModel? _existing;

  @override
  void initState() {
    super.initState();
    _recalcCountdown();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _recalcCountdown());
    _prefillExisting();
  }

  void _recalcCountdown() {
    final lockAt =
        widget.fixture.kickoff.subtract(const Duration(hours: 1));
    final remaining = lockAt.difference(DateTime.now());
    setState(() {
      _timeToLock = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  void _prefillExisting() {
    final existing = context
        .read<PredictionProvider>()
        .predictionForFixture(widget.fixture.fixtureId);
    if (existing != null) {
      setState(() {
        _existing = existing;
        _homeController.text = existing.homeGuess.toString();
        _awayController.text = existing.awayGuess.toString();
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _homeController.dispose();
    _awayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final home = int.tryParse(_homeController.text);
    final away = int.tryParse(_awayController.text);

    if (home == null || away == null || home < 0 || away < 0) {
      _showSnack('Enter valid scores (0 or above)', isError: true);
      return;
    }

    final user = context.read<AuthService>().userModel!;
    final ok = await context.read<PredictionProvider>().submitPrediction(
          userId: user.uid,
          fixture: widget.fixture,
          homeGuess: home,
          awayGuess: away,
        );

    if (!mounted) return;

    if (ok) {
      // Cancel the reminder — user has already predicted
      await NotificationService.cancelMatchReminder(widget.fixture.fixtureId);
      if (!mounted) return;
      _showSnack(
          _existing == null ? 'Prediction saved!' : 'Prediction updated!');
      Navigator.pop(context);
    } else {
      final err = context.read<PredictionProvider>().error;
      _showSnack(err ?? 'Something went wrong', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? Colors.red.shade700 : const Color(0xFF4CAF50),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.fixture.isLocked;
    final predProvider = context.watch<PredictionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${widget.fixture.homeTeam} vs ${widget.fixture.awayTeam}',
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MatchHeader(fixture: widget.fixture),
            const SizedBox(height: 16),
            locked
                ? const _LockedBanner()
                : _CountdownBanner(timeToLock: _timeToLock),
            const SizedBox(height: 24),
            _ScoreCard(
              homeTeam: widget.fixture.homeTeam,
              awayTeam: widget.fixture.awayTeam,
              homeController: _homeController,
              awayController: _awayController,
              isLocked: locked,
            ),
            const SizedBox(height: 32),
            if (!locked)
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: predProvider.isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    disabledBackgroundColor:
                        const Color(0xFF4CAF50).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: predProvider.isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _existing != null
                              ? 'Update Prediction'
                              : 'Submit Prediction',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            if (locked && _existing != null)
              _LockedPredictionSummary(prediction: _existing!),
          ],
        ),
      ),
    );
  }
}

// ── Match header ───────────────────────────────────────────────────────────────

class _MatchHeader extends StatelessWidget {
  final FixtureModel fixture;
  const _MatchHeader({required this.fixture});

  @override
  Widget build(BuildContext context) {
    final local = fixture.kickoff.toLocal();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final kickoffStr =
        '${weekdays[local.weekday - 1]} ${local.day} ${months[local.month - 1]}'
        '  •  ${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fixture.homeTeam,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('vs',
                    style: TextStyle(color: Colors.white38, fontSize: 14)),
              ),
              Expanded(
                child: Text(
                  fixture.awayTeam,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(kickoffStr,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Countdown / Locked banners ─────────────────────────────────────────────────

class _CountdownBanner extends StatelessWidget {
  final Duration timeToLock;
  const _CountdownBanner({required this.timeToLock});

  @override
  Widget build(BuildContext context) {
    final h = timeToLock.inHours.toString().padLeft(2, '0');
    final m = (timeToLock.inMinutes % 60).toString().padLeft(2, '0');
    final s = (timeToLock.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 10),
          const Text('Locks in ',
              style: TextStyle(color: Colors.white60, fontSize: 14)),
          Text(
            '$h:$m:$s',
            style: const TextStyle(
              color: Color(0xFF4CAF50),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock, color: Colors.redAccent, size: 20),
          SizedBox(width: 10),
          Text(
            'Prediction window closed',
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LockedPredictionSummary extends StatelessWidget {
  final PredictionModel prediction;
  const _LockedPredictionSummary({required this.prediction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF4CAF50), size: 18),
          const SizedBox(width: 8),
          Text(
            'Your prediction: '
            '${prediction.homeGuess} – ${prediction.awayGuess}',
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Score input card ───────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final TextEditingController homeController;
  final TextEditingController awayController;
  final bool isLocked;

  const _ScoreCard({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeController,
    required this.awayController,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLocked ? 'Your Prediction' : 'Enter Your Score',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(homeTeam,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    _ScoreStepper(
                        controller: homeController, isLocked: isLocked),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  '–',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(awayTeam,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    _ScoreStepper(
                        controller: awayController, isLocked: isLocked),
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

class _ScoreStepper extends StatelessWidget {
  final TextEditingController controller;
  final bool isLocked;

  const _ScoreStepper(
      {required this.controller, required this.isLocked});

  void _change(int delta) {
    final current = int.tryParse(controller.text) ?? 0;
    final next = (current + delta).clamp(0, 20);
    controller.text = next.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepBtn(
            icon: Icons.remove,
            onPressed: isLocked ? null : () => _change(-1)),
        Container(
          width: 60,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: TextField(
            controller: controller,
            enabled: !isLocked,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
          ),
        ),
        _StepBtn(
            icon: Icons.add,
            onPressed: isLocked ? null : () => _change(1)),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _StepBtn({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final active = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF4CAF50).withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF4CAF50).withOpacity(0.4)
                : Colors.white12,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? const Color(0xFF4CAF50) : Colors.white24,
        ),
      ),
    );
  }
}
