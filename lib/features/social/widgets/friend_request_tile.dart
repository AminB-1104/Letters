import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/user_summary.dart';
import 'user_list_tile.dart';

class FriendRequestTile extends StatelessWidget {
  const FriendRequestTile({
    super.key,
    required this.user,
    required this.onAccept,
    required this.onDecline,
    this.isBusy = false,
    this.onTap,
  });

  final UserSummary user;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trailing = isBusy
        ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Decline',
                icon: const Icon(Icons.close, color: AppColors.error),
                onPressed: onDecline,
              ),
              const SizedBox(width: AppSpacing.s4),
              IconButton(
                tooltip: 'Accept',
                icon: const Icon(Icons.check, color: AppColors.success),
                onPressed: onAccept,
              ),
            ],
          );

    return UserListTile(
      user: user,
      onTap: onTap,
      trailing: trailing,
    );
  }
}
