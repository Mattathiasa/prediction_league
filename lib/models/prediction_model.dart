import 'package:cloud_firestore/cloud_firestore.dart';

class PredictionModel {
  final String predictionId;
  final String userId;
  final String fixtureId;
  final int homeGuess;
  final int awayGuess;
  final int pointsEarned;
  final DateTime submittedAt;
  final bool locked;

  const PredictionModel({
    required this.predictionId,
    required this.userId,
    required this.fixtureId,
    required this.homeGuess,
    required this.awayGuess,
    this.pointsEarned = 0,
    required this.submittedAt,
    this.locked = false,
  });

  factory PredictionModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PredictionModel(
      predictionId: id,
      userId: data['userId'] as String,
      fixtureId: data['fixtureId'] as String,
      homeGuess: data['homeGuess'] as int,
      awayGuess: data['awayGuess'] as int,
      pointsEarned: data['pointsEarned'] as int? ?? 0,
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
      locked: data['locked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'predictionId': predictionId,
        'userId': userId,
        'fixtureId': fixtureId,
        'homeGuess': homeGuess,
        'awayGuess': awayGuess,
        'pointsEarned': pointsEarned,
        'submittedAt': Timestamp.fromDate(submittedAt),
        'locked': locked,
      };

  PredictionModel copyWith({
    int? homeGuess,
    int? awayGuess,
    int? pointsEarned,
    bool? locked,
  }) {
    return PredictionModel(
      predictionId: predictionId,
      userId: userId,
      fixtureId: fixtureId,
      homeGuess: homeGuess ?? this.homeGuess,
      awayGuess: awayGuess ?? this.awayGuess,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      submittedAt: submittedAt,
      locked: locked ?? this.locked,
    );
  }
}
