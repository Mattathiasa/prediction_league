import 'package:cloud_firestore/cloud_firestore.dart';

class FixtureModel {
  final String fixtureId;
  final String homeTeam;
  final String awayTeam;
  final DateTime kickoff;
  final int? homeScore;
  final int? awayScore;
  final String status; // upcoming | live | finished
  final String competition;

  const FixtureModel({
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoff,
    this.homeScore,
    this.awayScore,
    required this.status,
    required this.competition,
  });

  // Prediction window closes 1 hour before kickoff
  bool get isLocked =>
      DateTime.now().isAfter(kickoff.subtract(const Duration(hours: 1)));

  bool get isFinished => status == 'finished';
  bool get isLive => status == 'live';
  bool get isUpcoming => status == 'upcoming';

  // ── From Firestore ──────────────────────────────────────────────────────────
  factory FixtureModel.fromFirestore(Map<String, dynamic> data, String id) {
    return FixtureModel(
      fixtureId: id,
      homeTeam: data['homeTeam'] as String,
      awayTeam: data['awayTeam'] as String,
      kickoff: (data['kickoff'] as Timestamp).toDate(),
      homeScore: data['homeScore'] as int?,
      awayScore: data['awayScore'] as int?,
      status: data['status'] as String? ?? 'upcoming',
      competition: data['competition'] as String? ?? 'Premier League',
    );
  }

  Map<String, dynamic> toMap() => {
        'fixtureId': fixtureId,
        'homeTeam': homeTeam,
        'awayTeam': awayTeam,
        'kickoff': Timestamp.fromDate(kickoff),
        'homeScore': homeScore,
        'awayScore': awayScore,
        'status': status,
        'competition': competition,
      };
}
