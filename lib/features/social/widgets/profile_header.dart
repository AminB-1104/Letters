import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/user_profile.dart';
import 'user_avatar.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            UserAvatar(
              displayName: profile.user.displayName,
              avatarUrl: profile.user.avatar,
              radius: 36,
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.user.displayName,
                    style: AppTextStyles.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '@${profile.user.username}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s20),
          Text(profile.bio, style: AppTextStyles.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.s20),
        Row(
          children: [
            _MetaChip(
              icon: Icons.people_outline,
              label: '${profile.friendCount} '
                  '${profile.friendCount == 1 ? 'friend' : 'friends'}',
            ),
            if (profile.createdAt != null) ...[
              const SizedBox(width: AppSpacing.s12),
              _MetaChip(
                icon: Icons.calendar_today_outlined,
                label: 'Joined ${_formatDate(profile.createdAt!)}',
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.onSurfaceMuted),
          const SizedBox(width: AppSpacing.s8),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
