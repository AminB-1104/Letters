import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _navTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      context.goNamed(RouteNames.home);
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
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
