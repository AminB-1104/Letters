// ignore_for_file: prefer_initializing_formals
// Reason: keep `friendService` as the public named param; the private
// `_friendService` field is bound via the initializer list, matching the
// convention used by AuthProvider and other services in this project.

import 'package:flutter/foundation.dart';

import '../models/user_summary.dart';
import '../services/friend_service.dart';
import 'user_provider.dart';

class FriendProvider extends ChangeNotifier {
  FriendProvider({required FriendService friendService})
      : _friendService = friendService;

  final FriendService _friendService;

  SocialStatus _friendsStatus = SocialStatus.idle;
  List<UserSummary> _friends = const [];

  SocialStatus _requestsStatus = SocialStatus.idle;
  List<UserSummary> _incoming = const [];
  List<UserSummary> _outgoing = const [];

  final Set<String> _busyUserIds = <String>{};
  String? _error;

  SocialStatus get friendsStatus => _friendsStatus;
  List<UserSummary> get friends => _friends;

  SocialStatus get requestsStatus => _requestsStatus;
  List<UserSummary> get incoming => _incoming;
  List<UserSummary> get outgoing => _outgoing;

  Set<String> get busyUserIds => Set.unmodifiable(_busyUserIds);
  bool isBusy(String userId) => _busyUserIds.contains(userId);
  String? get error => _error;

  Future<void> loadFriends() async {
    _friendsStatus = SocialStatus.loading;
    _error = null;
    notifyListeners();

    final result = await _friendService.listFriends();
    result.fold(
      onSuccess: (list) {
        _friends = list;
        _friendsStatus = SocialStatus.success;
        notifyListeners();
      },
      onFailure: (err) {
        _error = err.message;
        _friendsStatus = SocialStatus.failure;
        notifyListeners();
      },
    );
  }

  Future<void> loadRequests() async {
    _requestsStatus = SocialStatus.loading;
    _error = null;
    notifyListeners();

    final result = await _friendService.listRequests();
    result.fold(
      onSuccess: (bundle) {
        _incoming = bundle.incoming;
        _outgoing = bundle.outgoing;
        _requestsStatus = SocialStatus.success;
        notifyListeners();
      },
      onFailure: (err) {
        _error = err.message;
        _requestsStatus = SocialStatus.failure;
        notifyListeners();
      },
    );
  }

  Future<bool> sendRequest(UserSummary user) async {
    return _runAction(user.id, () async {
      final result = await _friendService.sendRequest(user.id);
      return result.fold(
        onSuccess: (_) {
          _outgoing = [..._outgoing, user];
          return true;
        },
        onFailure: (err) {
          _error = err.message;
          return false;
        },
      );
    });
  }

  Future<bool> acceptRequest(UserSummary user) async {
    return _runAction(user.id, () async {
      final result = await _friendService.acceptRequest(user.id);
      return result.fold(
        onSuccess: (_) {
          _incoming = _incoming.where((u) => u.id != user.id).toList();
          if (!_friends.any((u) => u.id == user.id)) {
            _friends = [..._friends, user];
          }
          return true;
        },
        onFailure: (err) {
          _error = err.message;
          return false;
        },
      );
    });
  }

  Future<bool> declineRequest(UserSummary user) async {
    return _runAction(user.id, () async {
      final result = await _friendService.declineRequest(user.id);
      return result.fold(
        onSuccess: (_) {
          _incoming = _incoming.where((u) => u.id != user.id).toList();
          return true;
        },
        onFailure: (err) {
          _error = err.message;
          return false;
        },
      );
    });
  }

  Future<bool> removeFriend(UserSummary user) async {
    return _runAction(user.id, () async {
      final result = await _friendService.removeFriend(user.id);
      return result.fold(
        onSuccess: (_) {
          _friends = _friends.where((u) => u.id != user.id).toList();
          return true;
        },
        onFailure: (err) {
          _error = err.message;
          return false;
        },
      );
    });
  }

  Future<bool> _runAction(String userId, Future<bool> Function() action) async {
    if (_busyUserIds.contains(userId)) return false;
    _busyUserIds.add(userId);
    _error = null;
    notifyListeners();
    try {
      final ok = await action();
      notifyListeners();
      return ok;
    } finally {
      _busyUserIds.remove(userId);
      notifyListeners();
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void reset() {
    _friends = const [];
    _incoming = const [];
    _outgoing = const [];
    _friendsStatus = SocialStatus.idle;
    _requestsStatus = SocialStatus.idle;
    _busyUserIds.clear();
    _error = null;
    notifyListeners();
  }
}
