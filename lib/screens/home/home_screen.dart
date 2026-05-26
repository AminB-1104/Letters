import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../providers/app_settings_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = settings.themeMode == ThemeMode.dark;
    final displayName = auth.currentUser?.displayName;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Letters'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: settings.toggleTheme,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName != null ? 'Welcome, $displayName' : 'Welcome',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'You are signed in. Messaging arrives in Phase 03.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s32),
            const Expanded(
              child: AppEmptyState(
                icon: Icons.forum_outlined,
                title: 'No conversations yet',
                message: 'Once messaging ships, your chats will appear here.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
