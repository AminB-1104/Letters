// ignore_for_file: prefer_initializing_formals
// Reason: keep `friendProvider` as the public named param; the private
// `_friendProvider` field is bound via the initializer list, matching the
// convention used elsewhere in this project.

import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import 'friend_provider.dart';

class SocialProvider extends ChangeNotifier {
  SocialProvider({required FriendProvider friendProvider})
      : _friendProvider = friendProvider {
    _rebuild();
    _friendProvider.addListener(_rebuild);
  }

  final FriendProvider _friendProvider;

  Map<String, RelationshipStatus> _relationshipMap = const {};

  Map<String, RelationshipStatus> get relationshipMap => _relationshipMap;

  RelationshipStatus relationshipFor(String userId) {
    return _relationshipMap[userId] ?? RelationshipStatus.none;
  }

  void _rebuild() {
    final next = <String, RelationshipStatus>{};
    for (final u in _friendProvider.friends) {
      next[u.id] = RelationshipStatus.friend;
    }
    for (final u in _friendProvider.incoming) {
      next[u.id] = RelationshipStatus.requestReceived;
    }
    for (final u in _friendProvider.outgoing) {
      next[u.id] = RelationshipStatus.requestSent;
    }
    _relationshipMap = Map.unmodifiable(next);
    notifyListeners();
  }

  void reset() {
    _relationshipMap = const {};
    notifyListeners();
  }

  @override
  void dispose() {
    _friendProvider.removeListener(_rebuild);
    super.dispose();
  }
}
