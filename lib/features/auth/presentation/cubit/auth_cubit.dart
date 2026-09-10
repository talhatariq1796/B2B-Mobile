import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';

/// Real login against the confirmed backend, replacing the earlier mock.
/// Kept as `Cubit<bool>` (same shape as the mock it replaces) since the
/// rest of the app only ever needs "is there a signed-in session," not a
/// richer auth state machine — Login owns the loading/error UI itself via
/// [logIn]'s return value.
class AuthCubit extends Cubit<bool> {
  // [restoredSession] seeds state from a still-valid token found in secure
  // storage at app startup (see main.dart) — without it, a signed-in user
  // would be asked to log in again on every app launch even though their
  // session hasn't actually expired. [restoredUsername] does the same for
  // [username] (see its doc comment).
  AuthCubit(this._repository, {bool restoredSession = false, String? restoredUsername})
    : username = restoredUsername,
      super(restoredSession);

  final AuthRepository _repository;

  // The backend's login call returns only a bearer token + expiry — no
  // profile/display name for the signed-in user (see
  // AuthRemoteDataSource.authenticate) — so this is simply the username the
  // person typed into the login form, kept for Settings to display. A
  // plain mutable field alongside the Cubit<bool> `state`, not part of it:
  // it always changes together with `state` (set here, then emitted below /
  // cleared in [logOut]), so any listener reacting to `state` sees it
  // already up to date.
  String? username;

  /// Returns a user-facing error message on failure, or null on success
  /// (state is already updated to `true` by the time this returns).
  Future<String?> logIn({required String username, required String password}) async {
    final result = await _repository.login(username: username, password: password);
    return result.fold((failure) => failure.message, (_) {
      this.username = username;
      emit(true);
      return null;
    });
  }

  Future<void> logOut() async {
    await _repository.logout();
    username = null;
    emit(false);
  }
}
