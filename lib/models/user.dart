class User {
  final String id;
  final String username;
  final String displayName;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      createdAt: createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}
