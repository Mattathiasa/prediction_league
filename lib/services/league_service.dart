import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/league_model.dart';
import '../models/matchup_model.dart';
import '../models/user_model.dart';

class LeagueService {
  // Resolved lazily rather than in the initialiser list so that constructing
  // the service does not require an initialised Firebase app — the pure helpers
  // below can then be exercised in a plain unit test.
  final FirebaseFirestore? _dbOverride;

  LeagueService({FirebaseFirestore? db}) : _dbOverride = db;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

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
  /// There is no Cloud Function layer on the Spark plan, so this reads the
  /// league directly — firestore.rules relaxes league reads to any signed-in
  /// user precisely so this lookup works, since leagues hold nothing
  /// sensitive and the invite code remains the real gate. The actual join is
  /// a client transaction so a concurrent join from someone else is handled
  /// by Firestore's normal optimistic-concurrency retry; the rules' hard
  /// `memberIds.size() <= 20` check is what actually prevents two joins both
  /// landing at 19/20, not this pre-check.
  Future<String> joinLeagueByCode({
    required String code,
    required String userId,
  }) async {
    final inviteCode = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(inviteCode)) {
      throw Exception('Invite codes are 6 letters or digits');
    }

    final matches = await _db
        .collection('leagues')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (matches.docs.isEmpty) {
      throw Exception('No league found with that code');
    }

    final leagueRef = matches.docs.first.reference;

    try {
      return await _db.runTransaction<String>((tx) async {
        final snap = await tx.get(leagueRef);
        if (!snap.exists) {
          throw Exception('League no longer exists');
        }

        final memberIds =
            List<String>.from(snap.data()?['memberIds'] as List? ?? const []);
        if (memberIds.contains(userId)) return snap.id;

        if (memberIds.length >= maxLeagueMembers) {
          throw Exception('This league is full ($maxLeagueMembers members)');
        }

        tx.update(leagueRef, {
          'memberIds': FieldValue.arrayUnion([userId]),
        });
        return snap.id;
      });
    } on FirebaseException catch (e) {
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
