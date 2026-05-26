// ignore_for_file: prefer_initializing_formals
// Reason: keep `chatService` as the public named param; the private
// `_chatService` field is bound via the initializer list, matching the
// convention used by AuthProvider and the social providers in this project.

import 'package:flutter/foundation.dart';

import '../../social/models/user_summary.dart';
import '../../social/providers/user_provider.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({required ChatService chatService})
      : _chatService = chatService;

  final ChatService _chatService;

  SocialStatus _listStatus = SocialStatus.idle;
  List<Chat> _chats = const [];

  final Set<String> _busyUserIds = <String>{};
  String? _error;

  SocialStatus get listStatus => _listStatus;
  List<Chat> get chats => _chats;
  String? get error => _error;
  bool isBusy(String userId) => _busyUserIds.contains(userId);

  Future<void> loadChats() async {
    _listStatus = SocialStatus.loading;
    _error = null;
    notifyListeners();

    final result = await _chatService.listChats();
    result.fold(
      onSuccess: (list) {
        _chats = list;
        _listStatus = SocialStatus.success;
        notifyListeners();
      },
      onFailure: (err) {
        _error = err.message;
        _listStatus = SocialStatus.failure;
        notifyListeners();
      },
    );
  }

  // Creates a chat with the given user (or returns the existing one — backend
  // is idempotent). Hoists the chat to the top of the list and returns it so
  // the caller can navigate to /chat/<id>.
  Future<Chat?> createOrOpenChat(UserSummary other) async {
    if (_busyUserIds.contains(other.id)) return null;
    _busyUserIds.add(other.id);
    _error = null;
    notifyListeners();

    try {
      final result = await _chatService.createChat(other.id);
      return result.fold(
        onSuccess: (chat) {
          _upsertAtTop(chat);
          notifyListeners();
          return chat;
        },
        onFailure: (err) {
          _error = err.message;
          notifyListeners();
          return null;
        },
      );
    } finally {
      _busyUserIds.remove(other.id);
      notifyListeners();
    }
  }

  // Called by MessageProvider after a successful send so the chat list can
  // reorder + update its preview without a server round-trip.
  void touchChatWithMessage(Message m) {
    final idx = _chats.indexWhere((c) => c.id == m.chatId);
    if (idx == -1) return;

    final preview = MessagePreview(
      id: m.id,
      senderId: m.senderId,
      content: m.content,
      type: m.type,
      createdAt: m.createdAt,
    );

    final updated = _chats[idx].copyWith(
      lastMessage: preview,
      updatedAt: m.createdAt,
    );

    final next = [..._chats]..removeAt(idx);
    next.insert(0, updated);
    _chats = next;
    notifyListeners();
  }

  void _upsertAtTop(Chat chat) {
    final next = _chats.where((c) => c.id != chat.id).toList();
    next.insert(0, chat);
    _chats = next;
  }

  Chat? findById(String chatId) {
    for (final c in _chats) {
      if (c.id == chatId) return c;
    }
    return null;
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  void reset() {
    _chats = const [];
    _listStatus = SocialStatus.idle;
    _busyUserIds.clear();
    _error = null;
    notifyListeners();
  }
}
