import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/image_preview_viewer.dart';
import '../../../../core/widgets/sticky_action_bar.dart';
import '../../../leads/presentation/cubit/lead_store_cubit.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../capture_flow.dart';

/// Shown immediately after every capture (camera or gallery). The card is
/// already persisted locally at this point — captured/addCaptured() saves
/// it as `pending` before this screen even opens — so this screen is
/// purely the decision point ARCHITECTURE.md describes: extract now, or
/// keep capturing and come back to it later. Nothing here can lose data;
/// "Save & capture next" doesn't need to do any additional saving, it
/// just skips extraction and returns to the camera immediately, which is
/// what keeps rapid event capture fast.
class CapturePreviewScreen extends StatelessWidget {
  const CapturePreviewScreen({required this.leadId, super.key});

  final String leadId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeadStoreCubit, List<Lead>>(
      builder: (context, leads) {
        final lead = leads.firstWhere((l) => l.id == leadId);
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(title: const Text('Card captured')),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onTap: lead.imagePath == null
                            ? null
                            : () => openImagePreview(context, localPath: lead.imagePath),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.lgRadius,
                              boxShadow: AppShadows.card,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: lead.imagePath == null
                                ? const Center(child: Icon(Icons.badge_outlined, size: 32))
                                : Image.file(File(lead.imagePath!), fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _BackOfCardRow(
                        backImagePath: lead.backImagePath,
                        onTap: () => launchBackCapture(context, leadId),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm + 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: AppRadius.mdRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 15, color: AppColors.success),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Saved on this device — nothing is lost, even offline.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('What would you like to do?', style: AppTextStyles.titleSm()),
                      const SizedBox(height: 4),
                      Text(
                        'You can extract this card\'s details now, or keep scanning and '
                        'come back to it later from the Leads list.',
                        style: AppTextStyles.bodySm(),
                      ),
                    ],
                  ),
                ),
              ),
              StickyActionBar(
                children: [
                  AppButton.ghost(
                    label: 'Capture next',
                    icon: Icons.camera_alt_outlined,
                    onPressed: () => context.pushReplacement('/capture/live'),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: AppButton.primary(
                      label: 'Extract data now',
                      icon: Icons.arrow_forward_rounded,
                      expand: true,
                      onPressed: () => context.pushReplacement('/leads/$leadId/review'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Optional second capture for cards with info printed on both sides. Sent
/// alongside the front photo under the same `card_image` multipart field
/// when extraction runs (see LeadStoreCubit.extract) — confirmed live that
/// the backend accepts both files under that key and returns the back
/// image back as `card_image_back`; not independently confirmed that OCR
/// actually reads the back side (tested with plain placeholder images, not
/// a real two-sided card), so double-check extracted fields on a real card.
class _BackOfCardRow extends StatelessWidget {
  const _BackOfCardRow({required this.backImagePath, required this.onTap});

  final String? backImagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBack = backImagePath != null;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            if (hasBack)
              GestureDetector(
                onTap: () => openImagePreview(context, localPath: backImagePath),
                child: ClipRRect(
                  borderRadius: AppRadius.smRadius,
                  child: Image.file(
                    File(backImagePath!),
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Icon(Icons.flip_camera_android_outlined, size: 18, color: AppColors.ink3),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                hasBack ? 'Back of card added' : 'Card has info on the back?',
                style: AppTextStyles.bodySm(),
              ),
            ),
            Text(
              hasBack ? 'Retake' : 'Add photo',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
