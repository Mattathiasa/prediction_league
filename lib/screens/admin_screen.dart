import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
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
  final AdminService _adminService = AdminService();

  bool _isAdmin = false;
  bool _checkingAdmin = true;
  bool _resetting = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAdmin());
  }

  // AuthService already resolved isAdmin against admin_roles (replacing the
  // old checkAdmin callable) by the time this screen can be reached — reuse
  // it rather than re-checking.
  Future<void> _checkAdmin() async {
    final auth = context.read<AuthService>();
    final isAdmin = auth.adminChecked ? auth.isAdmin : false;

    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _checkingAdmin = false;
    });

    if (!isAdmin) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin access required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Opportunistic weekly reset — there is no scheduler on Spark, so this
    // runs the Monday reset the first time an admin opens this screen in a
    // new ISO week instead. See AdminService.
    unawaited(_adminService.maybeAutoResetWeeklyPoints());
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
      await _adminService.resetWeeklyPointsNow();
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
