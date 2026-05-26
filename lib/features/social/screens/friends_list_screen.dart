import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../../chat/providers/chat_provider.dart';
import '../models/user_summary.dart';
import '../providers/friend_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/user_list_tile.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final friend = context.read<FriendProvider>();
      if (friend.friendsStatus == SocialStatus.idle) {
        friend.loadFriends();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final friend = context.watch<FriendProvider>();
    final body = _buildBody(friend);
    return RefreshIndicator(
      onRefresh: () => friend.loadFriends(),
      child: body,
    );
  }

  Widget _buildBody(FriendProvider friend) {
    switch (friend.friendsStatus) {
      case SocialStatus.idle:
      case SocialStatus.loading:
        if (friend.friends.isEmpty) {
          return ListView(children: const [
            SizedBox(height: 120),
            AppLoader(),
          ]);
        }
        return _list(friend);
      case SocialStatus.failure:
        return ListView(children: [
          const SizedBox(height: 80),
          AppErrorState(
            message: friend.error ?? 'Could not load friends.',
            onRetry: () => friend.loadFriends(),
          ),
        ]);
      case SocialStatus.success:
        if (friend.friends.isEmpty) {
          return ListView(children: const [
            SizedBox(height: 80),
            AppEmptyState(
              icon: Icons.people_outline,
              title: 'No friends yet',
              message: 'Use Search to find people you know.',
            ),
          ]);
        }
        return _list(friend);
    }
  }

  Widget _list(FriendProvider friend) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.s16),
      itemCount: friend.friends.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
      itemBuilder: (context, index) {
        final user = friend.friends[index];
        return UserListTile(
          user: user,
          onTap: () => context.goNamed(
            RouteNames.userProfile,
            pathParameters: {'username': user.username},
          ),
          trailing: _FriendTrailing(user: user),
        );
      },
    );
  }
}

class _FriendTrailing extends StatelessWidget {
  const _FriendTrailing({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final friend = context.watch<FriendProvider>();
    if (friend.isBusy(user.id)) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return PopupMenuButton<_FriendMenuItem>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert, color: AppColors.onSurfaceMuted),
      onSelected: (item) async {
        switch (item) {
          case _FriendMenuItem.message:
            await _openChat(context, user);
            break;
          case _FriendMenuItem.viewProfile:
            context.goNamed(
              RouteNames.userProfile,
              pathParameters: {'username': user.username},
            );
            break;
          case _FriendMenuItem.remove:
            await _confirmRemove(context, user);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _FriendMenuItem.message,
          child: Text('Send message'),
        ),
        PopupMenuItem(
          value: _FriendMenuItem.viewProfile,
          child: Text('View profile'),
        ),
        PopupMenuItem(
          value: _FriendMenuItem.remove,
          child: Text('Remove friend'),
        ),
      ],
    );
  }

  Future<void> _openChat(BuildContext context, UserSummary user) async {
    final chats = context.read<ChatProvider>();
    final chat = await chats.createOrOpenChat(user);
    if (chat == null) {
      if (context.mounted && chats.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(chats.error!)),
        );
      }
      return;
    }
    if (!context.mounted) return;
    context.goNamed(
      RouteNames.chatScreen,
      pathParameters: {'chatId': chat.id},
    );
  }

  Future<void> _confirmRemove(BuildContext context, UserSummary user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
          'You will be unfriended from ${user.displayName}. You can send '
          'a new request later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final friend = context.read<FriendProvider>();
    final ok = await friend.removeFriend(user);
    if (!ok && context.mounted && friend.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friend.error!)),
      );
    }
  }
}

enum _FriendMenuItem { message, viewProfile, remove }
