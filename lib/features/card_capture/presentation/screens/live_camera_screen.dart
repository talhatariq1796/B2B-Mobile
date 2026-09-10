import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../leads/presentation/cubit/lead_store_cubit.dart';
import '../../image_storage.dart';

/// A real live camera preview — this is the actual "when the camera opens"
/// screen. It's a separate, custom camera implementation (the `camera`
/// package) rather than the native OS camera sheet (`image_picker`'s
/// ImageSource.camera): the native camera app is a separate process/view
/// Flutter can't draw over. This screen owns the preview, so a
/// card-placement guide could be drawn directly on top of it later — a
/// guide overlay was removed for now, see git history to restore it.
///
/// Note: iOS Simulator has no camera hardware — this screen will show its
/// "camera unavailable" state there. It needs a physical device to test
/// the live preview for real.
class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({this.attachToLeadId, super.key});

  // When set, the captured photo is attached as this lead's back-of-card
  // photo instead of starting a new lead — see [launchBackCapture].
  final String? attachToLeadId;

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Locking to portrait removes a whole class of preview sizing/rotation
    // bugs — the math below assumes portrait, and card scanning is a
    // portrait-held gesture anyway.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initFuture = _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _initFuture = _initCamera());
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = "This device doesn't have a usable camera.");
        return;
      }
      final rearCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              "Couldn't access the camera — check camera permission in Settings.",
        );
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final persistedPath = await persistCapturedImage(file.path, isFromCamera: true);
      if (!mounted) return;
      final attachToLeadId = widget.attachToLeadId;
      if (attachToLeadId != null) {
        context.read<LeadStoreCubit>().setBackImage(
          attachToLeadId,
          backImagePath: persistedPath,
        );
        if (context.mounted) context.pop();
        return;
      }
      final lead = context.read<LeadStoreCubit>().addCaptured(
        imagePath: persistedPath,
      );
      if (context.mounted) context.pushReplacement('/leads/${lead.id}/preview');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not capture the photo — try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snapshot) {
              if (_error != null) {
                return _CameraError(
                  message: _error!,
                  onRetry: () => setState(() {
                    _error = null;
                    _initFuture = _initCamera();
                  }),
                );
              }
              final controller = _controller;
              if (controller == null || !controller.value.isInitialized) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              return _FilledCameraPreview(controller: controller);
            },
          ),
          // Card placement guide removed for now.
          // Align (not a bare Stack child) so the button keeps its own
          // small size instead of being forced to fill the whole screen —
          // that's what was stretching its circular background into an
          // oval spanning the full width, with the icon stranded in the
          // middle of it.
          Align(
            alignment: Alignment.topLeft,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _CircleIconButton(
                  icon: Icons.close_rounded,
                  onTap: () => context.pop(),
                ),
              ),
            ),
          ),
          if (_controller?.value.isInitialized ?? false)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Center the card, then capture',
                        style: AppTextStyles.bodySm(
                          color: Colors.white.withValues(alpha: .85),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 72,
                          height: 72,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: _capturing
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fills and crops the preview to the full screen. `previewSize` is always
/// reported in the camera's native sensor orientation — landscape,
/// width > height — regardless of how the phone is actually held; the
/// widget CameraPreview draws is already correctly rotated for display,
/// but sizing it with the *unswapped* width/height (or with
/// `controller.value.aspectRatio` directly, which is defined as that same
/// landscape width/height) stretches a portrait preview into a
/// wide/squashed, fisheye-looking result and can leave it short of filling
/// the screen. Swapping width/height here — the standard fix for this
/// well-known `camera` plugin gotcha — and letting `BoxFit.cover` do the
/// crop avoids both problems.
class _FilledCameraPreview extends StatelessWidget {
  const _FilledCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const SizedBox.expand();

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .4),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white70,
              size: 34,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
