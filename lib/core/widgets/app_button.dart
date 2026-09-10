import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';

enum AppButtonSize { md, lg }

/// Primary/ghost button pair used everywhere in the app. `loading` shows a
/// spinner in place of the label/icon and disables the tap target — callers
/// don't need to separately manage disabling the button while an async
/// action runs.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.size = AppButtonSize.md,
    super.key,
  }) : _ghost = false;

  const AppButton.ghost({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.size = AppButtonSize.md,
    super.key,
  }) : _ghost = true;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final AppButtonSize size;
  final bool _ghost;

  @override
  Widget build(BuildContext context) {
    final vPad = size == AppButtonSize.lg ? 15.0 : 12.0;
    final textStyle = TextStyle(
      fontSize: size == AppButtonSize.lg ? 14.5 : 13,
      fontWeight: FontWeight.w600,
    );
    final spinnerColor = _ghost ? AppColors.inkSoft : Colors.white;

    final child = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: spinnerColor,
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 7),
                Icon(icon, size: 15),
              ],
            ],
          );

    if (_ghost) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkSoft,
          disabledForegroundColor: AppColors.inkSoft,
          side: const BorderSide(color: AppColors.border),
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: vPad),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
          textStyle: textStyle,
        ),
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: .45),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: vPad),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
        textStyle: textStyle,
      ),
      child: child,
    );
  }
}

/// Small circular icon-only affordance (e.g. gallery shortcut on Capture).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    this.background = AppColors.surface,
    this.foreground = AppColors.primary,
    this.size = 44.0,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: foreground, size: size * .42),
        ),
      ),
    );
  }
}
