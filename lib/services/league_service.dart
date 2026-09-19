import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/league_model.dart';
import '../models/user_model.dart';
import '../models/matchup_model.dart';

class LeagueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Invite code ────────────────────────────────────────────────────────────

  static const int maxLeagueMembers = 20;

  String generateInviteCode() {
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

  Future<LeagueModel> joinLeagueByCode({
    required String code,
    required String userId,
  }) async {
    final snap = await _db
        .collection('leagues')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('No league found with that code. Check it and try again.');
    }

    final doc = snap.docs.first;

    // Use transaction to prevent race condition on member cap check
    return _db.runTransaction((tx) async {
      final leagueDoc = await tx.get(doc.reference);
      final league = LeagueModel.fromFirestore(leagueDoc.data()!, leagueDoc.id);

      if (league.memberIds.contains(userId)) {
        throw Exception('You are already a member of "${league.name}".');
      }

      if (league.memberIds.length >= maxLeagueMembers) {
        throw Exception(
            'This league is full (${league.memberIds.length}/$maxLeagueMembers members).');
      }

      tx.update(doc.reference, {
        'memberIds': FieldValue.arrayUnion([userId]),
      });

      return LeagueModel(
        leagueId: league.leagueId,
        name: league.name,
        adminId: league.adminId,
        memberIds: [...league.memberIds, userId],
        inviteCode: league.inviteCode,
        createdAt: league.createdAt,
      );
    });
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<LeagueModel>> userLeaguesStream(String userId) {
    return _db
        .collection('leagues')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LeagueModel.fromFirestore(d.data(), d.id))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  }

  // Fetches member UserModels for a league, sorted by totalPoints desc.
  // Chunks into batches of 10 to respect Firestore's whereIn limit.
  Future<List<UserModel>> getLeagueMembers(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];

    final chunks = <List<String>>[];
    for (var i = 0; i < memberIds.length; i += 10) {
      chunks.add(memberIds.sublist(
          i, i + 10 > memberIds.length ? memberIds.length : i + 10));
    }

    final futures = chunks.map((chunk) => _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: chunk)
        .get());

    final results = await Future.wait(futures);

    return results
        .expand((snap) =>
            snap.docs.map((d) => UserModel.fromFirestore(d.data(), d.id)))
        .toList()
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
  }

  // ── Head-to-head matchups ────────────────────────────────────────────────────

  /// Generates weekly head-to-head pairings using classic fantasy style:
  /// 1st seed vs last seed, 2nd vs 2nd-to-last, etc.
  /// The top seed gets a bye if the league has an odd number of members.
  List<LeagueMatchup> generateMatchups(List<UserModel> members) {
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
        matchups.add(LeagueMatchup(
          home: sorted[i],
          away: null,
          isBye: true,
        ));
        break;
      }

      // Assign home to top seed, away to bottom seed
      matchups.add(LeagueMatchup(
        home: sorted[i],
        away: sorted[j],
      ));
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

  // ── Admin ──────────────────────────────────────────────────────────────────

  Future<void> resetWeeklyPoints() async {
    final snap = await _db.collection('users').get();
    if (snap.docs.isEmpty) return;

    // Split into batches of 500 (Firestore batch limit)
    const batchSize = 500;
    for (var i = 0; i < snap.docs.length; i += batchSize) {
      final batch = _db.batch();
      final end = (i + batchSize < snap.docs.length)
          ? i + batchSize
          : snap.docs.length;
      for (final doc in snap.docs.sublist(i, end)) {
        batch.update(doc.reference, {'weeklyPoints': 0});
      }
      await batch.commit();
    }
  }
}
