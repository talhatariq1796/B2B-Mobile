import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/info_banner.dart';
import '../../../leads/presentation/cubit/lead_store_cubit.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../capture_flow.dart';

/// A dedicated scanning experience — full-bleed viewfinder with a scan-line
/// (the one purposeful animation on this screen: it communicates "actively
/// looking for a card," not decoration), a real camera/gallery picker, and
/// a persistent, calm guest-mode status rather than a bottom-nav-interrupting
/// banner. Note: iOS Simulator has no camera hardware, so "Take photo" only
/// works on a physical device; "Choose from gallery" works on both.
class CardCaptureScreen extends StatefulWidget {
  const CardCaptureScreen({super.key});

  @override
  State<CardCaptureScreen> createState() => _CardCaptureScreenState();
}

class _CardCaptureScreenState extends State<CardCaptureScreen>
    with SingleTickerProviderStateMixin {
  bool _picking = false;
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    setState(() => _picking = true);
    await pickCardImage(context, ImageSource.gallery);
    if (mounted) setState(() => _picking = false);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthCubit>().state;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  Text('Scan a card', style: AppTextStyles.displayMd()),
                  const Spacer(),
                  if (!isLoggedIn)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDim,
                        borderRadius: AppRadius.pillRadius,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Guest',
                            style: AppTextStyles.caption(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.huge,
                ),
                child: Column(
                  children: [
                    if (!isLoggedIn) ...[
                      InfoBanner(
                        icon: Icons.cloud_off_rounded,
                        tone: BannerTone.info,
                        message:
                            "You're working as a guest. Cards stay safely on this device — nothing is submitted until you log in.",
                        actionLabel: 'Log in',
                        onAction: () => context.push('/login'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    AspectRatio(
                      aspectRatio: 4 / 5,
                      child: ClipRRect(
                        borderRadius: AppRadius.xlRadius,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF0F3D3E),
                                    Color(0xFF0A2C2D),
                                  ],
                                ),
                              ),
                            ),
                            _ScanGuide(animation: _scanController),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 18,
                              child: Center(
                                child: Text(
                                  'Fit the card inside the frame',
                                  style: AppTextStyles.bodySm(
                                    color: Colors.white.withValues(alpha: .8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: AppColors.ink3,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Tap the camera button below to scan',
                            style: AppTextStyles.caption(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton.ghost(
                      label: 'Choose from gallery instead',
                      icon: Icons.photo_library_outlined,
                      loading: _picking,
                      onPressed: _picking
                          ? null
                          : () => _pickFromGallery(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (isLoggedIn)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 13,
                            color: AppColors.ink3,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Photo stays on-device until it syncs',
                            style: AppTextStyles.caption(),
                          ),
                        ],
                      ),
                    if (!isLoggedIn)
                      BlocBuilder<LeadStoreCubit, List<Lead>>(
                        builder: (context, leads) {
                          final pendingCount = leads
                              .where((l) => l.status == LeadStatus.pending)
                              .length;
                          if (pendingCount == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              '$pendingCount card${pendingCount == 1 ? '' : 's'} waiting on this device',
                              style: AppTextStyles.caption(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corner guide + a slow scan-line sweep — the only animation on this
/// screen, present because it communicates active scanning, not for show.
class _ScanGuide extends StatelessWidget {
  const _ScanGuide({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: .8,
        heightFactor: .5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const _Corner(alignment: Alignment.topLeft),
            const _Corner(alignment: Alignment.topRight),
            const _Corner(alignment: Alignment.bottomLeft),
            const _Corner(alignment: Alignment.bottomRight),
            AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment(0, -1 + animation.value * 2),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0),
                            AppColors.accent.withValues(alpha: .85),
                            AppColors.accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: isTop && isLeft ? const Radius.circular(6) : Radius.zero,
            topRight: isTop && !isLeft ? const Radius.circular(6) : Radius.zero,
            bottomLeft: !isTop && isLeft
                ? const Radius.circular(6)
                : Radius.zero,
            bottomRight: !isTop && !isLeft
                ? const Radius.circular(6)
                : Radius.zero,
          ),
        ),
      ),
    );
  }
}
