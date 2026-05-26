import '../../../core/services/api_service.dart';
import '../../../core/utils/result.dart';
import '../models/user_profile.dart';
import '../models/user_summary.dart';

class UserService {
  UserService(this._api);

  final ApiService _api;

  Future<Result<List<UserSummary>, ApiError>> search(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final result = await _api.get<Map<String, dynamic>>(
      '/api/users/search',
      query: {'q': query, 'page': page, 'limit': limit},
    );
    return result.fold(
      onSuccess: (data) {
        final list = (data['results'] as List<dynamic>? ?? const [])
            .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
        return Success(list);
      },
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<UserProfile, ApiError>> profile(String username) async {
    final result = await _api.get<Map<String, dynamic>>(
      '/api/users/profile/$username',
    );
    return result.fold(
      onSuccess: (data) {
        final userJson = data['user'] as Map<String, dynamic>;
        return Success(UserProfile.fromJson(userJson));
      },
      onFailure: (e) => Failure(e),
    );
  }
}
