import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/message.dart';
import 'relative_time.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.primary : AppColors.surface;
    final textColor = isMine ? AppColors.onPrimary : AppColors.onSurface;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppSpacing.radiusM),
      topRight: const Radius.circular(AppSpacing.radiusM),
      bottomLeft: Radius.circular(isMine ? AppSpacing.radiusM : AppSpacing.radiusS),
      bottomRight: Radius.circular(isMine ? AppSpacing.radiusS : AppSpacing.radiusM),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: align,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: radius,
                border: isMine
                    ? null
                    : Border.all(color: AppColors.border, width: 1),
              ),
              child: Text(
                message.content,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            shortTime(message.createdAt),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
