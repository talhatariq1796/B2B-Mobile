import 'dart:async';
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Two separate concerns, per ARCHITECTURE.md's image storage strategy:
///
/// - **App-local copy** (this function's return value) — the source of
///   truth the app actually reads from (thumbnails, review, upload later).
///   Copied into the app's own sandboxed storage so it survives regardless
///   of what happens to the original temp file the camera/picker handed
///   back, and independent of whatever the gallery does to its copy.
/// - **Gallery copy** — a best-effort courtesy save, camera captures only
///   (a gallery-picked image is already in the gallery). Never blocks or
///   fails the capture: if it fails, the app-local copy is still there and
///   that's all the app itself depends on.
///
/// Returns the new persistent app-local path.
Future<String> persistCapturedImage(String sourcePath, {required bool isFromCamera}) async {
  final appDir = await getApplicationSupportDirectory();
  final cardsDir = Directory('${appDir.path}/cards');
  if (!await cardsDir.exists()) {
    await cardsDir.create(recursive: true);
  }

  final ext = sourcePath.split('.').last;
  final fileName = '${DateTime.now().microsecondsSinceEpoch}.$ext';
  final destination = '${cardsDir.path}/$fileName';
  await File(sourcePath).copy(destination);

  if (isFromCamera) {
    // Fire-and-forget: a failure here (permission denied, no gallery
    // access, etc.) must never affect the capture itself.
    unawaited(_saveToGallery(destination));
  }

  return destination;
}

Future<void> _saveToGallery(String path) async {
  try {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) return;
    }
    await Gal.putImage(path, album: 'Agency Check-in');
  } catch (_) {
    // Best-effort only — the app-local copy is what the app relies on.
  }
}
