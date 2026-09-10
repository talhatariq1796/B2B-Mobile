import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] so the rest of the app depends
/// on this interface rather than the package directly (keystore/keychain-backed).
class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  static const _authTokenKey = 'auth_token';
  static const _tokenExpiresAtKey = 'auth_token_expires_at';
  static const _usernameKey = 'username';

  Future<void> saveAuthToken(String token, {DateTime? expiresAt}) async {
    await _storage.write(key: _authTokenKey, value: token);
    if (expiresAt != null) {
      await _storage.write(
        key: _tokenExpiresAtKey,
        value: expiresAt.toIso8601String(),
      );
    }
  }

  Future<String?> getAuthToken() => _storage.read(key: _authTokenKey);

  /// Null if never set, or if the stored value can't be parsed. Callers
  /// treat "unknown expiry" the same as "assume still valid until the
  /// backend says otherwise" — this app doesn't proactively refresh yet.
  Future<DateTime?> getTokenExpiresAt() async {
    final raw = await _storage.read(key: _tokenExpiresAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // The login server (see AuthRemoteDataSource.authenticate) returns only a
  // bearer token + expiry — no display name or profile info for the signed
  // in user. This is the username they typed into the login form, saved so
  // Settings can show who's signed in without re-asking them.
  Future<void> saveUsername(String username) =>
      _storage.write(key: _usernameKey, value: username);

  Future<String?> getUsername() => _storage.read(key: _usernameKey);

  Future<void> clear() => _storage.deleteAll();
}
