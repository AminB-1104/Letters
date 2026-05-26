// ignore_for_file: prefer_initializing_formals
// Reason: keep `messageService` / `chatProvider` as public named params; the
// private fields are bound via the initializer list, matching the convention
// used by AuthProvider and the social providers in this project.

import 'package:flutter/foundation.dart';

import '../../social/providers/user_provider.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import 'chat_provider.dart';

class MessageProvider extends ChangeNotifier {
  MessageProvider({
    required MessageService messageService,
    required ChatProvider chatProvider,
  })  : _messageService = messageService,
        _chatProvider = chatProvider;

  final MessageService _messageService;
  final ChatProvider _chatProvider;

  static const int _pageSize = 30;

  String? _currentChatId;
  SocialStatus _messagesStatus = SocialStatus.idle;
  SocialStatus _sendStatus = SocialStatus.idle;
  List<Message> _messages = const [];
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _error;

  String? get currentChatId => _currentChatId;
  SocialStatus get messagesStatus => _messagesStatus;
  SocialStatus get sendStatus => _sendStatus;
  List<Message> get messages => _messages;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  String? get error => _error;

  Future<void> openChat(String chatId) async {
    _currentChatId = chatId;
    _messages = const [];
    _page = 1;
    _hasMore = true;
    _error = null;
    _messagesStatus = SocialStatus.loading;
    notifyListeners();

    final result = await _messageService.listMessages(chatId, page: 1, limit: _pageSize);
    if (_currentChatId != chatId) return; // user navigated away; ignore
    result.fold(
      onSuccess: (list) {
        _messages = list;
        _hasMore = list.length == _pageSize;
        _messagesStatus = SocialStatus.success;
        notifyListeners();
      },
      onFailure: (err) {
        _error = err.message;
        _messagesStatus = SocialStatus.failure;
        notifyListeners();
      },
    );
  }

  Future<void> loadMore() async {
    final chatId = _currentChatId;
    if (chatId == null || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    notifyListeners();

    final nextPage = _page + 1;
    final result = await _messageService.listMessages(
      chatId,
      page: nextPage,
      limit: _pageSize,
    );
    if (_currentChatId != chatId) {
      _loadingMore = false;
      return;
    }
    result.fold(
      onSuccess: (list) {
        if (list.isEmpty) {
          _hasMore = false;
        } else {
          _messages = [..._messages, ...list];
          _page = nextPage;
          _hasMore = list.length == _pageSize;
        }
      },
      onFailure: (err) {
        _error = err.message;
      },
    );
    _loadingMore = false;
    notifyListeners();
  }

  Future<bool> sendMessage(String content) async {
    final chatId = _currentChatId;
    if (chatId == null) return false;
    final trimmed = content.trim();
    if (trimmed.isEmpty) return false;

    _sendStatus = SocialStatus.loading;
    _error = null;
    notifyListeners();

    final result = await _messageService.sendMessage(chatId, trimmed);
    return result.fold(
      onSuccess: (msg) {
        if (_currentChatId == chatId) {
          // Newest-first ordering — backend returns desc by createdAt, so the
          // newly sent message goes at index 0 of `_messages`.
          _messages = [msg, ..._messages];
        }
        _chatProvider.touchChatWithMessage(msg);
        _sendStatus = SocialStatus.success;
        notifyListeners();
        return true;
      },
      onFailure: (err) {
        _error = err.message;
        _sendStatus = SocialStatus.failure;
        notifyListeners();
        return false;
      },
    );
  }

  void closeChat() {
    _currentChatId = null;
    _messages = const [];
    _page = 1;
    _hasMore = true;
    _loadingMore = false;
    _messagesStatus = SocialStatus.idle;
    _sendStatus = SocialStatus.idle;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void reset() {
    closeChat();
  }
}
