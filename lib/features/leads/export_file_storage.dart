import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Writes an exported file's bytes to a temp location so it can be handed
/// to the share sheet — this is a transient file for the user to save/send
/// wherever they want, not app-local source-of-truth storage (contrast
/// `card_capture/image_storage.dart`, which persists into app support
/// storage since captured card images ARE the app's source of truth).
Future<String> saveExportFile(Uint8List bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$filename';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
