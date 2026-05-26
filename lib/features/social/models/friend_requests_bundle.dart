import 'user_summary.dart';

class FriendRequestsBundle {
  final List<UserSummary> incoming;
  final List<UserSummary> outgoing;

  const FriendRequestsBundle({
    required this.incoming,
    required this.outgoing,
  });

  factory FriendRequestsBundle.fromJson(Map<String, dynamic> json) {
    List<UserSummary> parseList(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw
          .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    return FriendRequestsBundle(
      incoming: parseList('incoming'),
      outgoing: parseList('outgoing'),
    );
  }
}
