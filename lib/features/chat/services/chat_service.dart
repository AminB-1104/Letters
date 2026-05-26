import '../../../core/services/api_service.dart';
import '../../../core/utils/result.dart';
import '../models/chat.dart';

class ChatService {
  ChatService(this._api);

  final ApiService _api;

  Future<Result<Chat, ApiError>> createChat(String otherUserId) async {
    final result = await _api.post<Map<String, dynamic>>(
      '/api/chats/create',
      body: {'userId': otherUserId},
    );
    return result.fold(
      onSuccess: (data) {
        final chatJson = data['chat'] as Map<String, dynamic>;
        return Success(Chat.fromJson(chatJson));
      },
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<List<Chat>, ApiError>> listChats({
    int page = 1,
    int limit = 20,
  }) async {
    final result = await _api.get<Map<String, dynamic>>(
      '/api/chats/list',
      query: {'page': page, 'limit': limit},
    );
    return result.fold(
      onSuccess: (data) {
        final list = (data['results'] as List<dynamic>? ?? const [])
            .map((e) => Chat.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
        return Success(list);
      },
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<Chat, ApiError>> getChat(String chatId) async {
    final result =
        await _api.get<Map<String, dynamic>>('/api/chats/$chatId');
    return result.fold(
      onSuccess: (data) {
        final chatJson = data['chat'] as Map<String, dynamic>;
        return Success(Chat.fromJson(chatJson));
      },
      onFailure: (e) => Failure(e),
    );
  }
}
