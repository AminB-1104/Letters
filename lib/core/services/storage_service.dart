import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._(this._prefs);

  static const String _authTokenKey = 'auth_token';
  static const String _themeModeKey = 'theme_mode';

  final SharedPreferences _prefs;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  String? getAuthToken() => _prefs.getString(_authTokenKey);

  Future<void> setAuthToken(String token) =>
      _prefs.setString(_authTokenKey, token);

  Future<void> clearAuthToken() => _prefs.remove(_authTokenKey);

  String? getThemeMode() => _prefs.getString(_themeModeKey);

  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_themeModeKey, mode);
}
