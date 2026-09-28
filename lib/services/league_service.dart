import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/league_model.dart';
import '../models/matchup_model.dart';
import '../models/user_model.dart';

class LeagueService {
  // Resolved lazily rather than in the initialiser list so that constructing
  // the service does not require an initialised Firebase app — the pure helpers
  // below can then be exercised in a plain unit test.
  final FirebaseFirestore? _dbOverride;
  final FirebaseFunctions? _functionsOverride;

  LeagueService({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _dbOverride = db,
        _functionsOverride = functions;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;

  // ── Invite code ────────────────────────────────────────────────────────────

  static const int maxLeagueMembers = 20;

  static String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── League CRUD ────────────────────────────────────────────────────────────

  Future<LeagueModel> createLeague({
    required String name,
    required String adminId,
    String? inviteCode,
  }) async {
    final code = inviteCode ?? generateInviteCode();
    final ref = _db.collection('leagues').doc();

    final league = LeagueModel(
      leagueId: ref.id,
      name: name.trim(),
      adminId: adminId,
      memberIds: [adminId],
      inviteCode: code,
      createdAt: DateTime.now(),
    );

    await ref.set(league.toMap());
    return league;
  }

  /// Joins a league by invite code.
  ///
  /// Delegates to the `joinLeague` callable rather than writing directly:
  /// finding a league by code requires reading a league the caller is not yet a
  /// member of, and allowing that from the client would mean making every
  /// league world-readable. The server also applies the member cap inside a
  /// transaction, so two simultaneous joins cannot both pass at 19/20.
  Future<String> joinLeagueByCode({required String code}) async {
    try {
      final result = await _functions
          .httpsCallable('joinLeague')
          .call<Map<String, dynamic>>(
        {'inviteCode': code.trim().toUpperCase()},
      );
      return result.data['leagueId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Could not join that league.');
    }
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<LeagueModel>> userLeaguesStream(String userId) {
    return _db
        .collection('leagues')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => LeagueModel.fromFirestore(d.data(), d.id))
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  /// Firestore rejects a `whereIn` filter with more than 10 values.
  static const int _whereInLimit = 10;

  /// Fetches member profiles for a league, sorted by totalPoints desc.
  ///
  /// Reads `/publicProfiles`, not `/users` — the latter is readable only by its
  /// owner, so this query used to be rejected outright and league standings
  /// never rendered.
  Future<List<UserModel>> getLeagueMembers(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];

    final chunks = <List<String>>[];
    for (var i = 0; i < memberIds.length; i += _whereInLimit) {
      final end = (i + _whereInLimit).clamp(0, memberIds.length);
      chunks.add(memberIds.sublist(i, end));
    }

    final results = await Future.wait(
      chunks.map(
        (chunk) => _db
            .collection('publicProfiles')
            .where(FieldPath.documentId, whereIn: chunk)
            .get(),
      ),
    );

    return results
        .expand(
          (snap) =>
              snap.docs.map((d) => UserModel.fromPublicProfile(d.data(), d.id)),
        )
        .toList()
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
  }

  // ── Head-to-head matchups ────────────────────────────────────────────────────

  /// Generates weekly head-to-head pairings using classic fantasy style:
  /// 1st seed vs last seed, 2nd vs 2nd-to-last, etc.
  /// The middle seed gets a bye if the league has an odd number of members.
  ///
  /// Pure — takes members, returns pairings, touches nothing else.
  static List<LeagueMatchup> generateMatchups(List<UserModel> members) {
    // Sort by weeklyPoints desc, totalPoints desc as tiebreaker
    final sorted = List<UserModel>.from(members)
      ..sort((a, b) {
        final cmp = b.weeklyPoints.compareTo(a.weeklyPoints);
        if (cmp != 0) return cmp;
        return b.totalPoints.compareTo(a.totalPoints);
      });

    final matchups = <LeagueMatchup>[];
    var i = 0;
    var j = sorted.length - 1;

    while (i <= j) {
      if (i == j) {
        // Odd one out — gets a bye
        matchups.add(
          LeagueMatchup(
            home: sorted[i],
            isBye: true,
          ),
        );
        break;
      }

      // Assign home to top seed, away to bottom seed
      matchups.add(
        LeagueMatchup(
          home: sorted[i],
          away: sorted[j],
        ),
      );
      i++;
      j--;
    }

    return matchups;
  }

  /// Fetch members and generate current week's matchups
  Future<List<LeagueMatchup>> getWeeklyMatchups(String leagueId) async {
    final leagueSnap = await _db.collection('leagues').doc(leagueId).get();
    if (!leagueSnap.exists) return [];

    final league = LeagueModel.fromFirestore(leagueSnap.data()!, leagueSnap.id);
    final members = await getLeagueMembers(league.memberIds);
    return generateMatchups(members);
  }
}
