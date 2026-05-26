import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _displayNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      username: _usernameCtrl.text.trim().toLowerCase(),
      displayName: _displayNameCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Sign up failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s24,
        vertical: AppSpacing.s24,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Create account', style: AppTextStyles.displayLarge),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'A few details and you\'re in.',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  AppTextField(
                    label: 'Username',
                    hint: 'lowercase letters, numbers, underscores',
                    controller: _usernameCtrl,
                    validator: Validators.username,
                    prefixIcon: Icons.alternate_email,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  AppTextField(
                    label: 'Display name',
                    hint: 'How others see you',
                    controller: _displayNameCtrl,
                    validator: Validators.displayName,
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  AppTextField(
                    label: 'Password',
                    hint: 'At least 6 characters',
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    validator: Validators.password,
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  AppTextField(
                    label: 'Confirm password',
                    hint: 'Repeat your password',
                    controller: _confirmCtrl,
                    obscureText: _obscure,
                    validator: (v) =>
                        Validators.confirmPassword(v, _passwordCtrl.text),
                    prefixIcon: Icons.lock_outline,
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  AppButton(
                    label: 'Create account',
                    onPressed: _submitting ? null : _submit,
                    isLoading: _submitting,
                    expand: true,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: AppTextStyles.bodyMedium,
                      ),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => context.goNamed(RouteNames.login),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
