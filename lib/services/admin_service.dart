import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin-only operations that aren't fixture-related, for the Spark-plan
/// deployment. Replaces the `resetWeeklyPointsNow` callable and the
/// Monday-07:00 `resetWeeklyPoints` schedule — there is no Cloud Functions
/// layer here, so this runs as a plain client write, gated by
/// firestore.rules' `isAdmin()` checks the same way fixture sync and scoring
/// are. See `FixtureService` and firestore.rules for the fuller picture.
class AdminService {
  final FirebaseFirestore _db;

  AdminService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  static const int _batchLimit = 500;

  /// Sets `weeklyPoints` to 0 for every user with a non-zero value, mirrored
  /// into `/publicProfiles`, and records when this last ran.
  Future<int> resetWeeklyPointsNow() async {
    final usersSnap = await _db.collection('users').get();
    final stale = usersSnap.docs
        .where((d) => (d.data()['weeklyPoints'] as int? ?? 0) != 0)
        .toList();

    final ops = <void Function(WriteBatch)>[];
    for (final doc in stale) {
      ops.add((b) => b.update(doc.reference, {'weeklyPoints': 0}));
      ops.add(
        (b) => b.update(
          _db.collection('publicProfiles').doc(doc.id),
          {'weeklyPoints': 0},
        ),
      );
    }

    for (var i = 0; i < ops.length; i += _batchLimit) {
      final batch = _db.batch();
      final end = (i + _batchLimit).clamp(0, ops.length);
      for (final op in ops.sublist(i, end)) {
        op(batch);
      }
      await batch.commit();
    }

    await _db.collection('meta').doc('weeklyReset').set({
      'lastRunWeekStart': _isoWeekStart(DateTime.now()).toIso8601String(),
    });

    return stale.length;
  }

  /// Runs the reset automatically the first time an admin opens the admin
  /// screen in a new ISO week. There is no true scheduler on Spark, so this
  /// is a best-effort substitute for the old Monday-07:00 scheduled
  /// function — a known limitation: if no admin opens the app that week, the
  /// reset simply doesn't happen until the next time one does.
  Future<void> maybeAutoResetWeeklyPoints() async {
    final markerSnap = await _db.collection('meta').doc('weeklyReset').get();
    final lastRun = markerSnap.data()?['lastRunWeekStart'] as String?;
    final currentWeekStart = _isoWeekStart(DateTime.now()).toIso8601String();
    if (lastRun == currentWeekStart) return;
    await resetWeeklyPointsNow();
  }

  static DateTime _isoWeekStart(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    return utc.subtract(Duration(days: utc.weekday - 1));
  }
}
