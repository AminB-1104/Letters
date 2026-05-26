import '../../../core/services/api_service.dart';
import '../../../core/utils/result.dart';
import '../../../models/user.dart';

class AuthSession {
  final User user;
  final String token;

  const AuthSession({required this.user, required this.token});
}

class AuthService {
  AuthService(this._api);

  final ApiService _api;

  Future<Result<AuthSession, ApiError>> register({
    required String username,
    required String displayName,
    required String password,
  }) async {
    final result = await _api.post<Map<String, dynamic>>(
      '/api/auth/register',
      body: {
        'username': username,
        'displayName': displayName,
        'password': password,
      },
    );
    return result.fold(
      onSuccess: (data) => Success(_parseSession(data)),
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<AuthSession, ApiError>> login({
    required String username,
    required String password,
  }) async {
    final result = await _api.post<Map<String, dynamic>>(
      '/api/auth/login',
      body: {'username': username, 'password': password},
    );
    return result.fold(
      onSuccess: (data) => Success(_parseSession(data)),
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<User, ApiError>> me() async {
    final result = await _api.get<Map<String, dynamic>>('/api/auth/me');
    return result.fold(
      onSuccess: (data) {
        final userJson = data['user'] as Map<String, dynamic>;
        return Success(User.fromJson(userJson));
      },
      onFailure: (e) => Failure(e),
    );
  }

  AuthSession _parseSession(Map<String, dynamic> data) {
    final userJson = data['user'] as Map<String, dynamic>;
    final token = data['token'] as String;
    return AuthSession(user: User.fromJson(userJson), token: token);
  }
}
