// ignore_for_file: prefer_initializing_formals
// Reason: keep `userService` as the public named param; the private `_userService`
// field is bound via the initializer list, matching the convention used by
// AuthProvider and other services in this project.

import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../models/user_summary.dart';
import '../services/user_service.dart';

enum SocialStatus { idle, loading, success, failure }

class UserProvider extends ChangeNotifier {
  UserProvider({required UserService userService})
      : _userService = userService;

  final UserService _userService;

  SocialStatus _searchStatus = SocialStatus.idle;
  List<UserSummary> _searchResults = const [];
  String _lastQuery = '';

  SocialStatus _profileStatus = SocialStatus.idle;
  UserProfile? _selectedProfile;

  String? _error;

  SocialStatus get searchStatus => _searchStatus;
  List<UserSummary> get searchResults => _searchResults;
  String get lastQuery => _lastQuery;

  SocialStatus get profileStatus => _profileStatus;
  UserProfile? get selectedProfile => _selectedProfile;

  String? get error => _error;

  Future<void> search(String query) async {
    final trimmed = query.trim();
    _lastQuery = trimmed;

    if (trimmed.isEmpty) {
      _searchResults = const [];
      _searchStatus = SocialStatus.idle;
      _error = null;
      notifyListeners();
      return;
    }

    _searchStatus = SocialStatus.loading;
    _error = null;
    notifyListeners();

    final result = await _userService.search(trimmed);
    if (_lastQuery != trimmed) {
      // A newer query has already been issued — ignore this response.
      return;
    }
    result.fold(
      onSuccess: (data) {
        _searchResults = data;
        _searchStatus = SocialStatus.success;
        notifyListeners();
      },
      onFailure: (err) {
        _searchResults = const [];
        _error = err.message;
        _searchStatus = SocialStatus.failure;
        notifyListeners();
      },
    );
  }

  void clearSearch() {
    _searchResults = const [];
    _lastQuery = '';
    _searchStatus = SocialStatus.idle;
    _error = null;
    notifyListeners();
  }

  Future<void> loadProfile(String username) async {
    _profileStatus = SocialStatus.loading;
    _selectedProfile = null;
    _error = null;
    notifyListeners();

    final result = await _userService.profile(username);
    result.fold(
      onSuccess: (profile) {
        _selectedProfile = profile;
        _profileStatus = SocialStatus.success;
        notifyListeners();
      },
      onFailure: (err) {
        _error = err.message;
        _profileStatus = SocialStatus.failure;
        notifyListeners();
      },
    );
  }

  void updateSelectedProfileRelationship(RelationshipStatus relationship) {
    final current = _selectedProfile;
    if (current == null) return;
    _selectedProfile = current.copyWith(relationship: relationship);
    notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void reset() {
    _searchResults = const [];
    _lastQuery = '';
    _searchStatus = SocialStatus.idle;
    _selectedProfile = null;
    _profileStatus = SocialStatus.idle;
    _error = null;
    notifyListeners();
  }
}
