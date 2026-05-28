import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/league_model.dart';
import '../models/user_model.dart';
import '../services/league_service.dart';

class LeagueProvider extends ChangeNotifier {
  final LeagueService _service = LeagueService();
  StreamSubscription<List<LeagueModel>>? _subscription;

  List<LeagueModel> _leagues = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  List<LeagueModel> get leagues => _leagues;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Called by ChangeNotifierProxyProvider — guard prevents duplicate subscriptions
  void startListening(String userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _subscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _subscription = _service.userLeaguesStream(userId).listen(
      (leagues) {
        _leagues = leagues;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _leagues = [];
    _currentUserId = null;
    _isLoading = false;
    notifyListeners();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<LeagueModel?> createLeague({
    required String name,
    required String adminId,
    String? inviteCode,
  }) async {
    _error = null;
    try {
      return await _service.createLeague(
          name: name, adminId: adminId, inviteCode: inviteCode);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<LeagueModel?> joinLeagueByCode({
    required String code,
    required String userId,
  }) async {
    _error = null;
    try {
      return await _service.joinLeagueByCode(code: code, userId: userId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<List<UserModel>> getLeagueMembers(List<String> memberIds) =>
      _service.getLeagueMembers(memberIds);

  Future<void> resetWeeklyPoints() => _service.resetWeeklyPoints();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
