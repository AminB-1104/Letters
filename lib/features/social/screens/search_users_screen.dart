import 'dart:async';

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
import '../../../core/widgets/app_text_field.dart';
import '../models/user_profile.dart';
import '../models/user_summary.dart';
import '../providers/friend_provider.dart';
import '../providers/social_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/user_list_tile.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  static const Duration _debounceDuration = Duration(milliseconds: 300);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      context.read<UserProvider>().search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        0,
      ),
      child: Column(
        children: [
          AppTextField(
            controller: _controller,
            hint: 'Search by username',
            prefixIcon: Icons.search,
            onChanged: _onChanged,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _debounce?.cancel();
                      context.read<UserProvider>().clearSearch();
                      setState(() {});
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Expanded(child: Consumer<UserProvider>(builder: _buildBody)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, UserProvider user, Widget? _) {
    switch (user.searchStatus) {
      case SocialStatus.idle:
        return const AppEmptyState(
          icon: Icons.search,
          title: 'Find friends',
          message: 'Type a username to discover other Letters users.',
        );
      case SocialStatus.loading:
        return const AppLoader();
      case SocialStatus.failure:
        return AppErrorState(
          message: user.error ?? 'Something went wrong.',
          onRetry: () => user.search(_controller.text),
        );
      case SocialStatus.success:
        if (user.searchResults.isEmpty) {
          return const AppEmptyState(
            icon: Icons.person_search,
            title: 'No matches',
            message: 'Try a different username.',
          );
        }
        return ListView.separated(
          itemCount: user.searchResults.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s8),
          itemBuilder: (context, index) {
            final summary = user.searchResults[index];
            return _SearchResultTile(summary: summary);
          },
        );
    }
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.summary});

  final UserSummary summary;

  @override
  Widget build(BuildContext context) {
    final friend = context.watch<FriendProvider>();
    final social = context.watch<SocialProvider>();
    final relationship = social.relationshipFor(summary.id);
    final isBusy = friend.isBusy(summary.id);

    return UserListTile(
      user: summary,
      onTap: () => context.goNamed(
        RouteNames.userProfile,
        pathParameters: {'username': summary.username},
      ),
      trailing: _RelationshipChip(
        relationship: relationship,
        isBusy: isBusy,
        onSend: () => friend.sendRequest(summary),
      ),
    );
  }
}

class _RelationshipChip extends StatelessWidget {
  const _RelationshipChip({
    required this.relationship,
    required this.isBusy,
    required this.onSend,
  });

  final RelationshipStatus relationship;
  final bool isBusy;
  final Future<bool> Function() onSend;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (relationship) {
      case RelationshipStatus.friend:
        return _StatusBadge(
          label: 'Friends',
          color: AppColors.success,
          icon: Icons.check,
        );
      case RelationshipStatus.requestSent:
        return _StatusBadge(
          label: 'Pending',
          color: AppColors.warning,
          icon: Icons.schedule,
        );
      case RelationshipStatus.requestReceived:
        return _StatusBadge(
          label: 'Respond',
          color: AppColors.primary,
          icon: Icons.mark_email_unread,
        );
      case RelationshipStatus.self:
        return Text('You', style: AppTextStyles.caption);
      case RelationshipStatus.none:
        return IconButton(
          tooltip: 'Send friend request',
          icon: const Icon(Icons.person_add_alt_1),
          color: AppColors.primary,
          onPressed: () async {
            final ok = await onSend();
            if (!ok && context.mounted) {
              final err = context.read<FriendProvider>().error;
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err)),
                );
              }
            }
          },
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.s4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
