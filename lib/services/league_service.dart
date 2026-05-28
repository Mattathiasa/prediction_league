import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/league_model.dart';
import '../models/user_model.dart';

class LeagueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Invite code ────────────────────────────────────────────────────────────

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
    final league = LeagueModel.fromFirestore(doc.data(), doc.id);

    if (league.memberIds.contains(userId)) {
      throw Exception('You are already a member of "${league.name}".');
    }

    await doc.reference.update({
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
