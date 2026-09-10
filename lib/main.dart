import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/di/injection_container.dart';
import 'core/storage/secure_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  final session = await _restoredSession();
  runApp(App(restoredSession: session.isValid, restoredUsername: session.username));
}

/// A signed-in user shouldn't have to log in again on every app launch —
/// the auth token itself is already persisted (secure storage), it just
/// wasn't being checked at startup. Treats "no expiry on record" as still
/// valid (this app doesn't proactively refresh tokens yet, same assumption
/// SecureStorageService.getTokenExpiresAt already documents); an expired
/// session is cleared here so a dead token doesn't linger indefinitely.
/// Also restores the username saved at login time (see AuthCubit's doc
/// comment — the backend's own login response carries no display name)
/// so Settings can show it right away instead of only after the next login.
Future<({bool isValid, String? username})> _restoredSession() async {
  final storage = sl<SecureStorageService>();
  final token = await storage.getAuthToken();
  if (token == null) return (isValid: false, username: null);
  final expiresAt = await storage.getTokenExpiresAt();
  if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
    await storage.clear();
    return (isValid: false, username: null);
  }
  return (isValid: true, username: await storage.getUsername());
}
