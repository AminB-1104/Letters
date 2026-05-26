import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../social/widgets/user_avatar.dart';
import '../models/chat.dart';
import 'relative_time.dart';

class ChatTile extends StatelessWidget {
  const ChatTile({super.key, required this.chat, this.onTap});

  final Chat chat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final preview = chat.lastMessage;
    final previewText = preview == null
        ? 'No messages yet'
        : preview.content;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            children: [
              UserAvatar(
                displayName: chat.other.displayName,
                avatarUrl: chat.other.avatar,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.other.displayName,
                            style: AppTextStyles.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          relativeTime(chat.updatedAt),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      previewText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: preview == null
                            ? AppColors.onSurfaceMuted
                            : AppColors.onSurface,
                        fontStyle: preview == null
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
