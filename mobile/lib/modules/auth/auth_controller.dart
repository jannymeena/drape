import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/network_provider.dart';
import '../../shared/services/session_store.dart';
import '../../shared/services/storage_service.dart';
import 'auth_service.dart';
import 'models/auth_response.dart';

/// In-memory auth state. The router gates on [SessionStore.state] (a sync
/// `ValueNotifier`); this notifier additionally exposes the signed-in user's
/// identity + onboarding status for screens that need it.
class AuthState {
  const AuthState({this.user});

  /// The most recent successful auth response, or null when signed out.
  final AuthResponse? user;

  bool get isAuthenticated => user != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._service, this._storage) : super(const AuthState());

  final AuthService _service;
  final StorageService _storage;

  /// Logs in with email/password. On success: persist tokens + identity to
  /// secure storage, flip the session flag (which the router watches), and
  /// publish the user into state. Returns the response so the caller can route
  /// on `onboardingCompleted` / `nextStep`. Throws [ApiException] on failure.
  Future<AuthResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _service.loginWithEmail(
      email: email,
      password: password,
    );
    await _storage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
    await _storage.saveIdentity(userId: response.userId, email: response.email);
    await SessionStore.setLoggedIn(true);
    state = AuthState(user: response);
    return response;
  }

  /// Clears tokens + session flag. The router's redirect bounces protected
  /// routes back to Welcome once the flag flips.
  Future<void> logout() async {
    await _storage.clearAll();
    await SessionStore.clear();
    state = const AuthState();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.read(authServiceProvider),
    ref.read(storageServiceProvider),
  );
});
