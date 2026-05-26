import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s16),
              AppButton(
                label: retryLabel,
                onPressed: onRetry,
                variant: AppButtonVariant.outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
