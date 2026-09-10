import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_shadows.dart';

/// Pins primary actions to the bottom of the screen, above the safe area,
/// with a soft top shadow separating it from scrolled content. Used
/// wherever a primary CTA must stay reachable regardless of scroll
/// position (Review & Correct, Outcome).
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.modal,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: children,
          ),
        ),
      ),
    );
  }
}
