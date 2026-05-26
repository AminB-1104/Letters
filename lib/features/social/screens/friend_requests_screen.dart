import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../models/user_summary.dart';
import '../providers/friend_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/friend_request_tile.dart';
import '../widgets/user_list_tile.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final friend = context.read<FriendProvider>();
      if (friend.requestsStatus == SocialStatus.idle) {
        friend.loadRequests();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final friend = context.watch<FriendProvider>();
    return RefreshIndicator(
      onRefresh: () => friend.loadRequests(),
      child: _buildBody(friend),
    );
  }

  Widget _buildBody(FriendProvider friend) {
    switch (friend.requestsStatus) {
      case SocialStatus.idle:
      case SocialStatus.loading:
        if (friend.incoming.isEmpty && friend.outgoing.isEmpty) {
          return ListView(children: const [SizedBox(height: 120), AppLoader()]);
        }
        return _list(friend);
      case SocialStatus.failure:
        return ListView(children: [
          const SizedBox(height: 80),
          AppErrorState(
            message: friend.error ?? 'Could not load requests.',
            onRetry: () => friend.loadRequests(),
          ),
        ]);
      case SocialStatus.success:
        if (friend.incoming.isEmpty && friend.outgoing.isEmpty) {
          return ListView(children: const [
            SizedBox(height: 80),
            AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No pending requests',
              message: 'You\'re all caught up.',
            ),
          ]);
        }
        return _list(friend);
    }
  }

  Widget _list(FriendProvider friend) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        _SectionHeader(
          label: 'Incoming',
          count: friend.incoming.length,
        ),
        const SizedBox(height: AppSpacing.s8),
        if (friend.incoming.isEmpty)
          _PlaceholderRow(text: 'No incoming requests')
        else
          ...friend.incoming.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: FriendRequestTile(
                user: u,
                isBusy: friend.isBusy(u.id),
                onAccept: () => _onAccept(context, u),
                onDecline: () => _onDecline(context, u),
                onTap: () => context.goNamed(
                  RouteNames.userProfile,
                  pathParameters: {'username': u.username},
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.s24),
        _SectionHeader(
          label: 'Sent',
          count: friend.outgoing.length,
        ),
        const SizedBox(height: AppSpacing.s8),
        if (friend.outgoing.isEmpty)
          _PlaceholderRow(text: 'No outgoing requests')
        else
          ...friend.outgoing.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: UserListTile(
                user: u,
                onTap: () => context.goNamed(
                  RouteNames.userProfile,
                  pathParameters: {'username': u.username},
                ),
                trailing: Text(
                  'Pending',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _onAccept(BuildContext context, UserSummary user) async {
    final friend = context.read<FriendProvider>();
    final ok = await friend.acceptRequest(user);
    if (!ok && context.mounted && friend.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friend.error!)),
      );
    }
  }

  Future<void> _onDecline(BuildContext context, UserSummary user) async {
    final friend = context.read<FriendProvider>();
    final ok = await friend.declineRequest(user);
    if (!ok && context.mounted && friend.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friend.error!)),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.titleMedium),
        const SizedBox(width: AppSpacing.s8),
        Text('($count)', style: AppTextStyles.caption),
      ],
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.onSurfaceMuted,
        ),
      ),
    );
  }
}
