class UserSummary {
  final String id;
  final String username;
  final String displayName;
  final String? avatar;

  const UserSummary({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatar,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        if (avatar != null) 'avatar': avatar,
      };
}
