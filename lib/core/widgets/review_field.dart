import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';

/// A labeled, editable value box. The "flagged" (low-confidence OCR) state
/// gets a full warning-tinted treatment — border, fill, and an inline note
/// with icon — so it reads as "look at this" at a glance, not just a
/// slightly-different border color easy to miss while scanning the form.
class ReviewField extends StatelessWidget {
  const ReviewField({
    required this.label,
    required this.controller,
    this.flagNote,
    this.maxLines = 1,
    this.icon,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? flagNote;
  final int maxLines;
  final IconData? icon;

  bool get _flagged => flagNote != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: AppTextStyles.label()),
            if (_flagged) ...[
              const SizedBox(width: 6),
              Icon(Icons.error_rounded, size: 12, color: AppColors.warning),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: AppTextStyles.body(),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: icon == null
                ? null
                : Align(
                    // A multiline field's prefixIcon centers on the whole
                    // (taller) field by default, while the text itself
                    // always starts at the top — top-aligning here keeps
                    // the icon level with the first line instead of
                    // floating in the middle of the box.
                    alignment: maxLines > 1 ? Alignment.topCenter : Alignment.center,
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Padding(
                      padding: maxLines > 1
                          ? const EdgeInsets.only(top: 12)
                          : EdgeInsets.zero,
                      child: Icon(
                        icon,
                        size: 17,
                        color: _flagged ? AppColors.warning : AppColors.ink3,
                      ),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 38,
              minHeight: 0,
            ),
            filled: true,
            fillColor: _flagged ? AppColors.warningBg : AppColors.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.mdRadius,
              borderSide: BorderSide(
                color: _flagged ? AppColors.warning : Colors.transparent,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdRadius,
              borderSide: BorderSide(
                color: _flagged ? AppColors.warning : Colors.transparent,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdRadius,
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.6,
              ),
            ),
          ),
        ),
        if (flagNote != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: AppColors.warning,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  flagNote!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
