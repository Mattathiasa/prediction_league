import 'package:flutter/foundation.dart';
import '../models/fixture_model.dart';
import '../services/fixture_service.dart';
import '../services/notification_service.dart';

class FixtureProvider extends ChangeNotifier {
  final FixtureService _service = FixtureService();

  bool _isLoading = false;
  String? _syncError;

  bool get isLoading => _isLoading;
  String? get syncError => _syncError;

  Stream<List<FixtureModel>> get fixturesStream => _service.upcomingFixtures();

  Future<void> syncFixtures() async {
    _isLoading = true;
    _syncError = null;
    notifyListeners();

    try {
      final upcoming = await _service.syncFixtures();
      // Schedule on-device reminders for every fixture not yet locked
      for (final fixture in upcoming) {
        await NotificationService.scheduleMatchReminder(
          fixtureId: fixture.fixtureId,
          homeTeam: fixture.homeTeam,
          awayTeam: fixture.awayTeam,
          kickoff: fixture.kickoff,
        );
      }
    } catch (e) {
      _syncError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
