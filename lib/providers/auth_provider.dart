// ignore_for_file: prefer_initializing_formals
// Reason: keep `storage` as the public named param; the private `_storage`
// field is bound via the initializer list.

import 'package:flutter/foundation.dart';

import '../core/services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required StorageService storage}) : _storage = storage;

  // ignore: unused_field
  final StorageService _storage;

  bool get isAuthenticated => false;

  Future<void> signIn({required String email, required String password}) {
    throw UnimplementedError('Auth flow is implemented in Phase 02');
  }

  Future<void> signOut() {
    throw UnimplementedError('Auth flow is implemented in Phase 02');
  }
}
