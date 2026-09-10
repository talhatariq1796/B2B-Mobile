import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_shadows.dart';

/// The base surface for grouped content — replaces plain bordered
/// `Container`s with a soft-shadow elevated card. Use [flat] for a
/// lower-emphasis variant (border only, no shadow) when many cards stack
/// densely (e.g. a long list) and full elevation would look noisy.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.flat = false,
    this.color = AppColors.surface,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool flat;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.lgRadius,
        border: flat ? Border.all(color: AppColors.border) : null,
        boxShadow: flat ? null : AppShadows.card,
      ),
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : Material(
              color: Colors.transparent,
              borderRadius: AppRadius.lgRadius,
              child: InkWell(
                onTap: onTap,
                borderRadius: AppRadius.lgRadius,
                child: Padding(padding: padding, child: child),
              ),
            ),
    );
    return content;
  }
}
