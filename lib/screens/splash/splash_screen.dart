import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/auth/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.status == AuthStatus.unknown) {
        auth.bootstrap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusL),
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                color: AppColors.onPrimary,
                size: 44,
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            Text('Letters', style: AppTextStyles.displayLarge),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Real conversations, in your inbox.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}
