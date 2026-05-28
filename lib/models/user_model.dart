class UserModel {
  final String uid;
  final String displayName;
  final String photoUrl;
  final int totalPoints;
  final int weeklyPoints;
  final int streak;
  final int bestStreak;
  final double accuracy;
  final List<String> badgeIds;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    this.totalPoints = 0,
    this.weeklyPoints = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.accuracy = 0.0,
    this.badgeIds = const [],
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      totalPoints: data['totalPoints'] as int? ?? 0,
      weeklyPoints: data['weeklyPoints'] as int? ?? 0,
      streak: data['streak'] as int? ?? 0,
      bestStreak: data['bestStreak'] as int? ?? 0,
      accuracy: (data['accuracy'] as num? ?? 0).toDouble(),
      badgeIds: List<String>.from(data['badgeIds'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'totalPoints': totalPoints,
        'weeklyPoints': weeklyPoints,
        'streak': streak,
        'bestStreak': bestStreak,
        'accuracy': accuracy,
        'badgeIds': badgeIds,
      };

  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    int? totalPoints,
    int? weeklyPoints,
    int? streak,
    int? bestStreak,
    double? accuracy,
    List<String>? badgeIds,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      totalPoints: totalPoints ?? this.totalPoints,
      weeklyPoints: weeklyPoints ?? this.weeklyPoints,
      streak: streak ?? this.streak,
      bestStreak: bestStreak ?? this.bestStreak,
      accuracy: accuracy ?? this.accuracy,
      badgeIds: badgeIds ?? this.badgeIds,
    );
  }
}
