import '../../../core/services/api_service.dart';
import '../../../core/utils/result.dart';
import '../models/message.dart';

class MessageService {
  MessageService(this._api);

  final ApiService _api;

  Future<Result<Message, ApiError>> sendMessage(
    String chatId,
    String content,
  ) async {
    final result = await _api.post<Map<String, dynamic>>(
      '/api/messages/send',
      body: {'chatId': chatId, 'content': content},
    );
    return result.fold(
      onSuccess: (data) {
        final json = data['message'] as Map<String, dynamic>;
        return Success(Message.fromJson(json));
      },
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<List<Message>, ApiError>> listMessages(
    String chatId, {
    int page = 1,
    int limit = 30,
  }) async {
    final result = await _api.get<Map<String, dynamic>>(
      '/api/messages/$chatId',
      query: {'page': page, 'limit': limit},
    );
    return result.fold(
      onSuccess: (data) {
        final list = (data['results'] as List<dynamic>? ?? const [])
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
        return Success(list);
      },
      onFailure: (e) => Failure(e),
    );
  }
}
