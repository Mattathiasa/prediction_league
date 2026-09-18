import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/fixture_model.dart';
import '../models/prediction_model.dart';
import '../services/prediction_service.dart';

class PredictionProvider extends ChangeNotifier {
  final PredictionService _service = PredictionService();

  StreamSubscription<List<PredictionModel>>? _subscription;
  Stream<List<HistoryEntry>>? _historyStream;
  String? _historyUserId;

  // Keyed by fixtureId for O(1) lookup in fixture list
  Map<String, PredictionModel> _predictions = {};
  bool _isSubmitting = false;
  String? _error;

  Map<String, PredictionModel> get predictions => _predictions;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  PredictionModel? predictionForFixture(String fixtureId) =>
      _predictions[fixtureId];

  // Called by ChangeNotifierProxyProvider when auth state changes
  void startListening(String userId) {
    _subscription?.cancel();
    _predictions = {};
    _subscription = _service.userPredictions(userId).listen((list) {
      _predictions = {for (final p in list) p.fixtureId: p};
      notifyListeners();
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _predictions = {};
    notifyListeners();
  }

  Stream<List<HistoryEntry>> historyStream(String userId) {
    if (_historyStream == null || _historyUserId != userId) {
      _historyUserId = userId;
      _historyStream = _service.userHistory(userId);
    }
    return _historyStream!;
  }

  Future<bool> submitPrediction({
    required String userId,
    required FixtureModel fixture,
    required int homeGuess,
    required int awayGuess,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      await _service.submitPrediction(
        userId: userId,
        fixture: fixture,
        homeGuess: homeGuess,
        awayGuess: awayGuess,
      );
      // Optimistic local update — stream will confirm shortly after
      final docId = '${userId}_${fixture.fixtureId}';
      _predictions[fixture.fixtureId] = PredictionModel(
        predictionId: docId,
        userId: userId,
        fixtureId: fixture.fixtureId,
        homeGuess: homeGuess,
        awayGuess: awayGuess,
        submittedAt: DateTime.now(),
      );
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _historyStream = null;
    super.dispose();
  }
}
