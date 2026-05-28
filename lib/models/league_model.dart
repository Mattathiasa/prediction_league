import 'package:cloud_firestore/cloud_firestore.dart';

class LeagueModel {
  final String leagueId;
  final String name;
  final String adminId;
  final List<String> memberIds;
  final String inviteCode;
  final DateTime createdAt;

  const LeagueModel({
    required this.leagueId,
    required this.name,
    required this.adminId,
    required this.memberIds,
    required this.inviteCode,
    required this.createdAt,
  });

  factory LeagueModel.fromFirestore(Map<String, dynamic> data, String id) {
    return LeagueModel(
      leagueId: id,
      name: data['name'] as String,
      adminId: data['adminId'] as String,
      memberIds: List<String>.from(data['memberIds'] as List),
      inviteCode: data['inviteCode'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'adminId': adminId,
        'memberIds': memberIds,
        'inviteCode': inviteCode,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
