import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { filled, outlined, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.isLoading = false,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.s8),
              ],
              Text(label, style: AppTextStyles.button),
            ],
          );

    final padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.s20,
      vertical: AppSpacing.s12,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusM),
    );

    final Widget button = switch (variant) {
      AppButtonVariant.filled => FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            padding: padding,
            shape: shape,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          child: child,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding: padding,
            shape: shape,
            side: const BorderSide(color: AppColors.primary),
            foregroundColor: AppColors.primary,
          ),
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            padding: padding,
            shape: shape,
            foregroundColor: AppColors.primary,
          ),
          child: child,
        ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
