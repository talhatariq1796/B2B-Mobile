import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

enum BannerTone { info, success, warning, danger }

/// A semantic banner used for any "here's the current state" message.
/// Distinct from a warning banner on purpose: guest mode, for example, is a
/// normal, intentional state — not a problem — so it uses [BannerTone.info]
/// (primary-tinted) rather than orange, which is reserved for things that
/// actually need attention.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.message,
    required this.icon,
    this.tone = BannerTone.info,
    this.actionLabel,
    this.onAction,
    this.trailing,
    super.key,
  });

  final String message;
  final IconData icon;
  final BannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      BannerTone.info => (AppColors.primary, AppColors.primaryDim),
      BannerTone.success => (AppColors.success, AppColors.successBg),
      BannerTone.warning => (AppColors.warning, AppColors.warningBg),
      BannerTone.danger => (AppColors.danger, AppColors.dangerBg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: AppTextStyles.bodySm(color: fg).copyWith(height: 1.4),
                ),
                if (actionLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: onAction,
                      child: Text(
                        actionLabel!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
