import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/user_provider.dart';
import '../../social/widgets/user_avatar.dart';
import '../providers/chat_provider.dart';
import '../providers/message_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scroll = ScrollController();
  MessageProvider? _messages;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Make sure the chat exists in ChatProvider so the AppBar can resolve
      // its title. If the chat list hasn't been loaded yet (deep-link entry),
      // kick off a load — ChatProvider is idempotent.
      final chats = context.read<ChatProvider>();
      if (chats.listStatus == SocialStatus.idle) {
        chats.loadChats();
      }
      _messages = context.read<MessageProvider>();
      _messages!.openChat(widget.chatId);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    // Stashed in initState so we don't touch `context` during teardown.
    _messages?.closeChat();
    super.dispose();
  }

  void _onScroll() {
    // reverse:true → scrolling to the visual top means hitting maxScrollExtent.
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      final messages = context.read<MessageProvider>();
      if (messages.hasMore && !messages.loadingMore) {
        messages.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.watch<MessageProvider>();
    final chat = context.select<ChatProvider, _ChatHeader>(
      (p) {
        final c = p.findById(widget.chatId);
        return _ChatHeader(
          displayName: c?.other.displayName ?? 'Chat',
          avatar: c?.other.avatar,
        );
      },
    );

    return AppScaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              displayName: chat.displayName,
              avatarUrl: chat.avatar,
              radius: 16,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                chat.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(messages)),
          const MessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessages(MessageProvider messages) {
    switch (messages.messagesStatus) {
      case SocialStatus.idle:
      case SocialStatus.loading:
        if (messages.messages.isEmpty) return const AppLoader();
        return _list(messages);
      case SocialStatus.failure:
        return AppErrorState(
          message: messages.error ?? 'Could not load messages.',
          onRetry: () => messages.openChat(widget.chatId),
        );
      case SocialStatus.success:
        if (messages.messages.isEmpty) {
          return const AppEmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'Say hello',
            message: 'No messages yet — break the ice.',
          );
        }
        return _list(messages);
    }
  }

  Widget _list(MessageProvider messages) {
    final myId = context.read<AuthProvider>().currentUser?.id;
    final itemCount = messages.messages.length + (messages.loadingMore ? 1 : 0);

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (messages.loadingMore && index == messages.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s12),
            child: AppLoader(size: 20),
          );
        }
        final msg = messages.messages[index];
        return MessageBubble(
          message: msg,
          isMine: msg.isMine(myId),
        );
      },
    );
  }
}

class _ChatHeader {
  final String displayName;
  final String? avatar;
  const _ChatHeader({required this.displayName, this.avatar});

  @override
  bool operator ==(Object other) =>
      other is _ChatHeader &&
      other.displayName == displayName &&
      other.avatar == avatar;

  @override
  int get hashCode => Object.hash(displayName, avatar);
}
