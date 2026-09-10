import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../leads/presentation/cubit/lead_store_cubit.dart';
import 'image_storage.dart';

/// The camera/gallery picker flow, shared by the bottom nav's center tab
/// and the Capture screen's own affordances — both should behave
/// identically. "Take photo" opens the in-app live camera screen (which
/// owns its own guide overlay); "Choose from gallery" goes through
/// image_picker directly, since a gallery pick has no camera preview to
/// overlay a guide on. Kept as free functions (not screen-scoped state) so
/// either call site can trigger it without needing to own the picker.
Future<void> launchCardCapture(BuildContext context) async {
  final source = await _chooseImageSource(context);
  if (source == null || !context.mounted) return;
  if (source == ImageSource.camera) {
    context.push('/capture/live');
    return;
  }
  await pickCardImage(context, source);
}

/// Picks directly from the given source, skipping the take-photo-or-gallery
/// sheet — used by the dedicated gallery shortcut icon, which is already an
/// explicit choice of source.
Future<void> pickCardImage(BuildContext context, ImageSource source) async {
  final picker = ImagePicker();
  XFile? file;
  try {
    file = await picker.pickImage(source: source, imageQuality: 90);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Camera unavailable — try a physical device or use the gallery instead.'
                : 'Could not open the photo library.',
          ),
        ),
      );
    }
    return;
  }
  if (file == null || !context.mounted) return;

  // Gallery picks are never re-saved to the gallery — they're already
  // there. Still copied into app-local storage so the app doesn't depend
  // on the original gallery asset staying valid/accessible.
  String persistedPath;
  try {
    persistedPath = await persistCapturedImage(file.path, isFromCamera: false);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this photo — try again.')),
      );
    }
    return;
  }
  if (!context.mounted) return;

  final lead = context.read<LeadStoreCubit>().addCaptured(imagePath: persistedPath);
  if (context.mounted) context.push('/leads/${lead.id}/preview');
}

/// Same take-photo-or-gallery choice as [launchCardCapture], but attaches
/// the result as [leadId]'s back-of-card photo instead of starting a new
/// lead — used from the capture preview screen once a front photo already
/// exists.
Future<void> launchBackCapture(BuildContext context, String leadId) async {
  final source = await _chooseImageSource(context);
  if (source == null || !context.mounted) return;
  if (source == ImageSource.camera) {
    context.push('/capture/live?attachTo=$leadId');
    return;
  }
  await pickBackImage(context, source, leadId);
}

Future<void> pickBackImage(BuildContext context, ImageSource source, String leadId) async {
  final picker = ImagePicker();
  XFile? file;
  try {
    file = await picker.pickImage(source: source, imageQuality: 90);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the photo library.')),
      );
    }
    return;
  }
  if (file == null || !context.mounted) return;

  String persistedPath;
  try {
    persistedPath = await persistCapturedImage(file.path, isFromCamera: false);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this photo — try again.')),
      );
    }
    return;
  }
  if (!context.mounted) return;

  context.read<LeadStoreCubit>().setBackImage(leadId, backImagePath: persistedPath);
}

Future<ImageSource?> _chooseImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.pillRadius,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add a business card',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          _SourceOption(
            icon: Icons.camera_alt_rounded,
            title: 'Take photo',
            subtitle: 'Use the camera to scan a card',
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          _SourceOption(
            icon: Icons.photo_library_rounded,
            title: 'Choose from gallery',
            subtitle: 'Pick a photo you already have',
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryDim,
          borderRadius: AppRadius.mdRadius,
        ),
        child: Icon(icon, color: AppColors.primary, size: 19),
      ),
      title: Text(title, style: AppTextStyles.titleSm()),
      subtitle: Text(subtitle, style: AppTextStyles.bodySm()),
    );
  }
}
