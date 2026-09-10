import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Small caps section label used to group related fields/content (e.g. the
/// Review screen's Contact / Agency / Address groups).
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.label(color: AppColors.primary),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
