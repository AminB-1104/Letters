import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../../social/providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_tile.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chats = context.read<ChatProvider>();
      if (chats.listStatus == SocialStatus.idle) {
        chats.loadChats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<ChatProvider>();
    return RefreshIndicator(
      onRefresh: () => chats.loadChats(),
      child: _buildBody(chats),
    );
  }

  Widget _buildBody(ChatProvider chats) {
    switch (chats.listStatus) {
      case SocialStatus.idle:
      case SocialStatus.loading:
        if (chats.chats.isEmpty) {
          return ListView(children: const [
            SizedBox(height: 120),
            AppLoader(),
          ]);
        }
        return _list(chats);
      case SocialStatus.failure:
        return ListView(children: [
          const SizedBox(height: 80),
          AppErrorState(
            message: chats.error ?? 'Could not load chats.',
            onRetry: () => chats.loadChats(),
          ),
        ]);
      case SocialStatus.success:
        if (chats.chats.isEmpty) {
          return ListView(children: const [
            SizedBox(height: 80),
            AppEmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No conversations yet',
              message: 'Tap the search icon above to find friends '
                  'and start a chat.',
            ),
          ]);
        }
        return _list(chats);
    }
  }

  Widget _list(ChatProvider chats) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.s16),
      itemCount: chats.chats.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
      itemBuilder: (context, index) {
        final chat = chats.chats[index];
        return ChatTile(
          chat: chat,
          onTap: () => context.goNamed(
            RouteNames.chatScreen,
            pathParameters: {'chatId': chat.id},
          ),
        );
      },
    );
  }
}
