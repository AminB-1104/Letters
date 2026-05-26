import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../models/user_profile.dart';
import '../models/user_summary.dart';
import '../providers/friend_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/profile_header.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.username});

  final String username;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserProvider>().loadProfile(widget.username);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    return AppScaffold(
      appBar: AppBar(
        title: Text('@${widget.username}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(RouteNames.search);
            }
          },
        ),
      ),
      body: _buildBody(user),
    );
  }

  Widget _buildBody(UserProvider user) {
    switch (user.profileStatus) {
      case SocialStatus.idle:
      case SocialStatus.loading:
        return const AppLoader();
      case SocialStatus.failure:
        return AppErrorState(
          message: user.error ?? 'Could not load profile.',
          onRetry: () => user.loadProfile(widget.username),
        );
      case SocialStatus.success:
        final profile = user.selectedProfile;
        if (profile == null) {
          return const AppErrorState(message: 'Profile unavailable.');
        }
        return _ProfileBody(profile: profile);
    }
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileHeader(profile: profile),
          const SizedBox(height: AppSpacing.s32),
          _RelationshipActions(profile: profile),
        ],
      ),
    );
  }
}

class _RelationshipActions extends StatelessWidget {
  const _RelationshipActions({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final friend = context.watch<FriendProvider>();
    final isBusy = friend.isBusy(profile.user.id);

    switch (profile.relationship) {
      case RelationshipStatus.self:
        return _InfoLine(text: 'This is your profile.');
      case RelationshipStatus.none:
        return AppButton(
          label: 'Add friend',
          icon: Icons.person_add_alt_1,
          isLoading: isBusy,
          expand: true,
          onPressed: () => _send(context, profile.user),
        );
      case RelationshipStatus.requestSent:
        return AppButton(
          label: 'Request pending',
          icon: Icons.schedule,
          variant: AppButtonVariant.outlined,
          expand: true,
          onPressed: null,
        );
      case RelationshipStatus.requestReceived:
        return Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Decline',
                variant: AppButtonVariant.outlined,
                isLoading: isBusy,
                onPressed: () => _decline(context, profile.user),
                expand: true,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: AppButton(
                label: 'Accept',
                icon: Icons.check,
                isLoading: isBusy,
                onPressed: () => _accept(context, profile.user),
                expand: true,
              ),
            ),
          ],
        );
      case RelationshipStatus.friend:
        return AppButton(
          label: 'Remove friend',
          icon: Icons.person_remove_alt_1,
          variant: AppButtonVariant.outlined,
          isLoading: isBusy,
          expand: true,
          onPressed: () => _confirmRemove(context, profile.user),
        );
    }
  }

  Future<void> _send(BuildContext context, UserSummary user) async {
    final friend = context.read<FriendProvider>();
    final userProvider = context.read<UserProvider>();
    final ok = await friend.sendRequest(user);
    if (ok) {
      userProvider.updateSelectedProfileRelationship(
        RelationshipStatus.requestSent,
      );
    } else if (context.mounted && friend.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friend.error!)),
      );
    }
  }

  Future<void> _accept(BuildContext context, UserSummary user) async {
    final friend = context.read<FriendProvider>();
    final userProvider = context.read<UserProvider>();
    final ok = await friend.acceptRequest(user);
    if (ok) {
      userProvider.updateSelectedProfileRelationship(RelationshipStatus.friend);
    } else if (context.mounted && friend.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friend.error!)),
      );
    }
  }

  Future<void> _decline(BuildContext context, UserSummary user) async {
    final friend = context.read<FriendProvider>();
    final userProvider = context.read<UserProvider>();
    final ok = await friend.declineRequest(user);
    if (ok) {
      userProvider.updateSelectedProfileRelationship(RelationshipStatus.none);
    } else if (context.mounted && friend.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friend.error!)),
      );
    }
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
    final userProvider = context.read<UserProvider>();
    final ok = await friend.removeFriend(user);
    if (ok) {
      userProvider.updateSelectedProfileRelationship(RelationshipStatus.none);
    } else if (context.mounted && friend.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friend.error!)),
      );
    }
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
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
