// ignore_for_file: prefer_initializing_formals
// Reason: keep `storage` and `authService` as public named params; the private
// fields are bound via the initializer list.

import 'package:flutter/foundation.dart';

import '../../../core/services/storage_service.dart';
import '../../../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required StorageService storage,
    required AuthService authService,
  })  : _storage = storage,
        _authService = authService;

  final StorageService _storage;
  final AuthService _authService;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _error;

  AuthStatus get status => _status;
  User? get currentUser => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> bootstrap() async {
    final token = _storage.getAuthToken();
    if (token == null || token.isEmpty) {
      _setUnauthenticated();
      return;
    }
    final result = await _authService.me();
    result.fold(
      onSuccess: (user) {
        _user = user;
        _status = AuthStatus.authenticated;
        _error = null;
        notifyListeners();
      },
      onFailure: (_) async {
        await _storage.clearAuthToken();
        _setUnauthenticated();
      },
    );
  }

  Future<bool> register({
    required String username,
    required String displayName,
    required String password,
  }) async {
    _error = null;
    final result = await _authService.register(
      username: username,
      displayName: displayName,
      password: password,
    );
    return result.fold(
      onSuccess: (session) async {
        await _storage.setAuthToken(session.token);
        _user = session.user;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      },
      onFailure: (err) {
        _error = err.message;
        notifyListeners();
        return false;
      },
    );
  }

  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    _error = null;
    final result = await _authService.login(
      username: username,
      password: password,
    );
    return result.fold(
      onSuccess: (session) async {
        await _storage.setAuthToken(session.token);
        _user = session.user;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      },
      onFailure: (err) {
        _error = err.message;
        notifyListeners();
        return false;
      },
    );
  }

  Future<void> signOut() async {
    await _storage.clearAuthToken();
    _setUnauthenticated();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void _setUnauthenticated() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
