import 'user_summary.dart';

enum RelationshipStatus {
  self,
  friend,
  requestSent,
  requestReceived,
  none,
}

RelationshipStatus _relationshipFromString(String? raw) {
  switch (raw) {
    case 'self':
      return RelationshipStatus.self;
    case 'friend':
      return RelationshipStatus.friend;
    case 'requestSent':
      return RelationshipStatus.requestSent;
    case 'requestReceived':
      return RelationshipStatus.requestReceived;
    case 'none':
    default:
      return RelationshipStatus.none;
  }
}

class UserProfile {
  final UserSummary user;
  final String bio;
  final DateTime? createdAt;
  final int friendCount;
  final RelationshipStatus relationship;

  const UserProfile({
    required this.user,
    required this.bio,
    required this.friendCount,
    required this.relationship,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    return UserProfile(
      user: UserSummary(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatar: json['avatar'] as String?,
      ),
      bio: (json['bio'] as String?) ?? '',
      createdAt: createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null,
      friendCount: (json['friendCount'] as num?)?.toInt() ?? 0,
      relationship: _relationshipFromString(json['relationship'] as String?),
    );
  }

  UserProfile copyWith({RelationshipStatus? relationship, int? friendCount}) {
    return UserProfile(
      user: user,
      bio: bio,
      createdAt: createdAt,
      friendCount: friendCount ?? this.friendCount,
      relationship: relationship ?? this.relationship,
    );
  }
}
