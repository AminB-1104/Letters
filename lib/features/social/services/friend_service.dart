import '../../../core/services/api_service.dart';
import '../../../core/utils/result.dart';
import '../models/friend_requests_bundle.dart';
import '../models/user_summary.dart';

class FriendService {
  FriendService(this._api);

  final ApiService _api;

  Future<Result<void, ApiError>> sendRequest(String userId) async {
    final result = await _api.post<dynamic>(
      '/api/friends/send-request',
      body: {'userId': userId},
    );
    return result.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<void, ApiError>> acceptRequest(String userId) async {
    final result = await _api.post<dynamic>(
      '/api/friends/accept-request',
      body: {'userId': userId},
    );
    return result.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<void, ApiError>> declineRequest(String userId) async {
    final result = await _api.post<dynamic>(
      '/api/friends/decline-request',
      body: {'userId': userId},
    );
    return result.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<void, ApiError>> removeFriend(String userId) async {
    final result = await _api.post<dynamic>(
      '/api/friends/remove-friend',
      body: {'userId': userId},
    );
    return result.fold(
      onSuccess: (_) => const Success(null),
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<List<UserSummary>, ApiError>> listFriends({
    int page = 1,
    int limit = 50,
  }) async {
    final result = await _api.get<Map<String, dynamic>>(
      '/api/friends/list',
      query: {'page': page, 'limit': limit},
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

  Future<Result<FriendRequestsBundle, ApiError>> listRequests() async {
    final result =
        await _api.get<Map<String, dynamic>>('/api/friends/requests');
    return result.fold(
      onSuccess: (data) => Success(FriendRequestsBundle.fromJson(data)),
      onFailure: (e) => Failure(e),
    );
  }
}
