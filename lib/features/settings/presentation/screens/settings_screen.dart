import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

/// Placeholder for real settings beyond the account card below, which is
/// real: it reads the actual signed-in state from [AuthCubit] and lets the
/// user log in/out for real.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>();
    final isLoggedIn = auth.state;
    final packageInfo = sl<PackageInfo>();
    final appVersion = packageInfo.buildNumber.isEmpty
        ? packageInfo.version
        : '${packageInfo.version} (${packageInfo.buildNumber})';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDim,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLoggedIn
                        ? Icons.person_rounded
                        : Icons.person_outline_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoggedIn ? (auth.username ?? 'Signed in') : 'Guest',
                        style: AppTextStyles.titleSm(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLoggedIn ? 'Signed in' : 'Not signed in',
                        style: AppTextStyles.bodySm(),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    if (isLoggedIn) {
                      context.read<AuthCubit>().logOut();
                    } else {
                      context.push('/login');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdRadius,
                    ),
                  ),
                  child: Text(isLoggedIn ? 'Log out' : 'Log in'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(title: 'About'),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.badge_outlined,
                  label: 'App version',
                  value: appVersion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.ink3),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTextStyles.body())),
          Text(value, style: AppTextStyles.bodySm(color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
