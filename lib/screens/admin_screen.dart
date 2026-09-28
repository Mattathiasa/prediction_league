import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/fixture_service.dart';
import '../theme/app_colors.dart';
import 'admin/admin_widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FixtureService _fixtureService = FixtureService();

  bool _isAdmin = false;
  bool _checkingAdmin = true;
  bool _resetting = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAdmin());
  }

  Future<void> _checkAdmin() async {
    setState(() => _checkingAdmin = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('checkAdmin')
          .call<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() => _isAdmin = result.data['isAdmin'] as bool? ?? false);
      if (!_isAdmin && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin access required'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin check failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAdmin) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Admin — Enter Results',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white70,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.sync, color: Colors.white70),
              tooltip: 'Sync fixtures from API',
              onPressed: _syncing ? null : _syncFixtures,
            ),
        ],
      ),
      body: _isAdmin
          ? Column(
              children: [
                Expanded(
                  child: AdminFixtureList(service: _fixtureService),
                ),
                ResetWeeklyPointsBar(
                  resetting: _resetting,
                  onReset: _resetWeeklyPoints,
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  Future<void> _resetWeeklyPoints() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Reset Weekly Points?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This sets every user\'s weeklyPoints to 0.\nThis cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _resetting = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('resetWeeklyPointsNow')
          .call<Map<String, dynamic>>();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weekly points reset to 0 for all users'),
          backgroundColor: AppColors.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _syncFixtures() async {
    setState(() => _syncing = true);
    try {
      final result = await _fixtureService.syncFixtures();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced ${result.length} upcoming fixtures'),
          backgroundColor: AppColors.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}

// ── Fixture list ──────────────────────────────────────────────────────────────

// ── Result entry bottom sheet ─────────────────────────────────────────────────

// ── Reset weekly points bar ───────────────────────────────────────────────────
