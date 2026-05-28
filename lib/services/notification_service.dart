import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'scoring_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _reminderChannelId = 'match_reminders';
  static const _resultChannelId = 'match_results';

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Match reminder (scheduled 1 hr before kickoff) ────────────────────────

  static Future<void> scheduleMatchReminder({
    required String fixtureId,
    required String homeTeam,
    required String awayTeam,
    required DateTime kickoff,
  }) async {
    final lockTime = kickoff.subtract(const Duration(hours: 1));
    if (!lockTime.isAfter(DateTime.now())) return; // window already closed

    final id = _notifId(fixtureId);
    final scheduled = tz.TZDateTime.from(lockTime, tz.local);

    await _plugin.zonedSchedule(
      id,
      '⏰ Time to predict!',
      '$homeTeam vs $awayTeam — submit before kick-off',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          'Match Reminders',
          channelDescription: 'Reminds you to predict before kick-off',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelMatchReminder(String fixtureId) async {
    await _plugin.cancel(_notifId(fixtureId));
  }

  // ── Instant result notification ───────────────────────────────────────────

  static Future<void> showResultNotification({
    required String homeTeam,
    required String awayTeam,
    required int homeScore,
    required int awayScore,
    int? pointsEarned,
  }) async {
    final String body;
    if (pointsEarned != null) {
      final sign = pointsEarned >= 0 ? '+' : '';
      body = '$sign$pointsEarned pts — ${ScoringService.pointsLabel(pointsEarned)}';
    } else {
      body = 'All predictions have been scored!';
    }

    await _plugin.show(
      0, // fixed ID — always shows the latest result
      '$homeTeam $homeScore – $awayScore $awayTeam',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _resultChannelId,
          'Match Results',
          channelDescription: 'Shows your points when a result is recorded',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // Stable int ID from fixtureId string, starting at 1 (0 is reserved for results)
  static int _notifId(String fixtureId) =>
      (fixtureId.hashCode.abs() % 99999) + 1;
}
