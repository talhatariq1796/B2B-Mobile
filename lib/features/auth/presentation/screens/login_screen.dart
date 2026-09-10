import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../cubit/auth_cubit.dart';

/// A branded moment, not a generic auth form: a dark hero zone with the
/// wordmark and a guest path with real button affordance instead of a text
/// link. Used to also have a workspace/microsite field pulled out of the
/// credential stack, but the backend's login response now embeds the
/// workspace itself (per the BE team's 2026-09-08 endpoint change), so
/// there's nothing left for that field to send — removed rather than kept
/// as a dead input.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loggingIn = false;
  bool _obscurePassword = true;
  String? _error;
  String? _usernameError;
  String? _passwordError;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _continueAsGuest() => context.go('/capture');

  Future<void> _login() async {
    final username = _username.text.trim();
    final password = _password.text;
    setState(() {
      _usernameError = username.isEmpty ? 'Enter your username' : null;
      _passwordError = password.isEmpty ? 'Enter your password' : null;
    });
    if (_usernameError != null || _passwordError != null) return;

    setState(() {
      _loggingIn = true;
      _error = null;
    });
    final error = await context.read<AuthCubit>().logIn(username: username, password: password);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loggingIn = false;
        _error = error;
      });
      return;
    }
    context.go('/capture');
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately not full-height-forced (no Spacer/IntrinsicHeight): the
    // dark hero region sizes to its own content, and everything below is
    // uniformly `bg`, so there's no seam/gap regardless of screen height or
    // content length.
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.fromLTRB(
                  24,
                  AppSpacing.xxxl,
                  24,
                  AppSpacing.xxl,
                ),
                child: _Wordmark(),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Welcome back', style: AppTextStyles.displayMd()),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in with your event staff account',
                      style: AppTextStyles.bodySm(),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.lgRadius,
                        boxShadow: AppShadows.card,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CredentialField(
                            label: 'Username',
                            controller: _username,
                            hint: 'username',
                            icon: Icons.person_outline_rounded,
                            errorText: _usernameError,
                            onChanged: (_) {
                              if (_usernameError != null) {
                                setState(() => _usernameError = null);
                              }
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _CredentialField(
                            label: 'Password',
                            controller: _password,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            onToggleObscure: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                            errorText: _passwordError,
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 15,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    AppButton.primary(
                      label: _loggingIn ? 'Signing in…' : 'Log in',
                      onPressed: _loggingIn ? null : _login,
                      expand: true,
                      loading: _loggingIn,
                      size: AppButtonSize.lg,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text('or', style: AppTextStyles.caption()),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.ghost(
                      label: 'Continue as guest',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _continueAsGuest,
                      expand: true,
                      size: AppButtonSize.lg,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: Text(
                        'You can capture cards as a guest — nothing is\nsubmitted until you sign in.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption().copyWith(height: 1.5),
                      ),
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

class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
          ),
          child: const Icon(
            Icons.badge_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Agency check-in',
          style: AppTextStyles.displayLg(color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          'TRADE SHOW · EVENT STAFF',
          style: AppTextStyles.eyebrow.copyWith(
            color: Colors.white.withValues(alpha: .6),
          ),
        ),
      ],
    );
  }
}

class _CredentialField extends StatelessWidget {
  const _CredentialField({
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.obscure = false,
    this.onToggleObscure,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? hint;
  final bool obscure;
  // Non-null shows a visibility-toggle icon in the field (used for password).
  final VoidCallback? onToggleObscure;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.label()),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: AppTextStyles.body(),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            errorText: errorText,
            prefixIcon: Icon(icon, size: 18, color: AppColors.ink3),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 0,
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.ink3,
                    ),
                    onPressed: onToggleObscure,
                  ),
            suffixIconConstraints: onToggleObscure == null
                ? null
                : const BoxConstraints(minWidth: 40, minHeight: 0),
          ),
        ),
      ],
    );
  }
}
