import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';

/// A dashboard summary stat: icon chip + label + big number. Replaces the
/// old flat gray `.stat` tile — the icon chip gives each stat a visual
/// anchor so the row reads at a glance instead of as four identical boxes.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.tone = StatTone.neutral,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      StatTone.neutral => (AppColors.primary, AppColors.primaryDim),
      StatTone.success => (AppColors.success, AppColors.successBg),
      StatTone.warning => (AppColors.warning, AppColors.warningBg),
      StatTone.danger => (AppColors.danger, AppColors.dangerBg),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: fg),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(value, style: AppTextStyles.statValue()),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppTextStyles.caption(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

enum StatTone { neutral, success, warning, danger }
