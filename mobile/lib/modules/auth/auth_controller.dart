import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import '../../shared/providers/session_epoch.dart';
import '../../shared/services/dashboard_cache.dart';
import '../../shared/services/session_store.dart';
import '../../shared/services/storage_service.dart';
import 'auth_service.dart';
import 'models/auth_response.dart';
import 'models/current_user.dart';

/// In-memory auth state. The router gates on [SessionStore.state] (a sync
/// `ValueNotifier`); this notifier additionally exposes the signed-in user's
/// session ([AuthResponse]: tokens + onboarding routing) and hydrated identity
/// ([CurrentUser] from `/users/me`) for screens that need them.
class AuthState {
  const AuthState({this.session, this.currentUser});

  /// The most recent login/signup response, or null when signed out.
  final AuthResponse? session;

  /// The hydrated `/users/me` identity, set on launch bootstrap. Null until the
  /// first successful fetch.
  final CurrentUser? currentUser;

  bool get isAuthenticated => session != null || currentUser != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._service, this._storage, this._ref)
      : super(const AuthState());

  final AuthService _service;
  final StorageService _storage;
  final Ref _ref;

  /// Logs in with email/password. On success: persist tokens + identity to
  /// secure storage, flip the session flag (which the router watches), and
  /// publish the session. Returns the response so the caller can route on
  /// `onboardingCompleted` / `nextStep`. Throws [ApiException] on failure.
  Future<AuthResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _service.loginWithEmail(
      email: email,
      password: password,
    );
    await _persistSession(response);
    return response;
  }

  /// Signs up with email/password. `display_name` is derived from the email
  /// local-part (the signup screen collects no name); the user can rename later
  /// in profile. On success: same persistence + session flip as login. Returns
  /// the response for routing. Throws [ApiException] on failure (e.g. 400
  /// `email_already_exists`).
  Future<AuthResponse> signupWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _service.signupWithEmail(
      email: email,
      password: password,
      displayName: _displayNameFromEmail(email),
    );
    await _persistSession(response);
    return response;
  }

  /// Requests a password-reset email. Succeeds whether or not the address has
  /// an account (the backend never reveals which). Throws [ApiException] only
  /// on validation/transport errors. No session change.
  Future<void> requestPasswordReset({required String email}) {
    return _service.requestPasswordReset(email: email);
  }

  /// Sets a new password from the reset-email token. On success the backend
  /// revokes all refresh tokens, so the caller routes to login. Throws
  /// [ApiException] on an invalid/expired token or weak password. No local
  /// session change (the reset flow runs signed-out).
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return _service.resetPassword(token: token, newPassword: newPassword);
  }

  /// On launch: if an access token is stored, hydrate identity via `/users/me`.
  /// An expired access token is refreshed transparently by the
  /// RefreshInterceptor (using the stored refresh token), so this succeeds for
  /// any user whose refresh token is still valid. Only a refresh that itself
  /// fails (refresh token expired/revoked ~30 days idle) surfaces as an
  /// [ApiException] here — we clear local state so the router falls back to
  /// Welcome. Returns true when a live session was restored, false otherwise.
  Future<bool> bootstrap() async {
    if (!await _storage.hasSession()) return false;
    try {
      final me = await _service.fetchCurrentUser();
      await SessionStore.setLoggedIn(true);
      state = AuthState(session: state.session, currentUser: me);
      return true;
    } on ApiException {
      await _clearSession();
      return false;
    }
  }

  /// Revokes the refresh token server-side (best-effort), then clears local
  /// tokens + session flag. The router's redirect bounces protected routes back
  /// to Welcome once the flag flips.
  Future<void> logout() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh != null) {
      try {
        await _service.logout(refreshToken: refresh);
      } on ApiException {
        // Best-effort: a failed server-side revoke must not block local sign-out.
      }
    }
    await _clearSession();
  }

  /// Replaces the hydrated identity (e.g. after a profile edit via
  /// `PATCH /users/{id}`) so every widget watching `currentUser` re-renders
  /// with the new name/email. Session tokens are unchanged.
  void applyCurrentUser(CurrentUser user) {
    state = AuthState(session: state.session, currentUser: user);
  }

  Future<void> _persistSession(AuthResponse response) async {
    await _storage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
    await _storage.saveIdentity(userId: response.userId, email: response.email);
    await SessionStore.setLoggedIn(true);
    state = AuthState(session: response, currentUser: state.currentUser);
    _bumpSessionEpoch();
  }

  Future<void> _clearSession() async {
    await _storage.clearAll();
    await SessionStore.clear();
    // Drop the cached dashboard so a different account on this device never
    // sees the previous user's outfits before the fresh frame loads.
    await DashboardCache().clear();
    state = const AuthState();
    _bumpSessionEpoch();
  }

  /// Rebuilds every provider that caches user-scoped in-memory state (they
  /// watch the epoch — see `session_epoch.dart`). Bumped on both sign-in and
  /// sign-out so no cross-account path can leak the previous user's data.
  void _bumpSessionEpoch() {
    _ref.read(sessionEpochProvider.notifier).state++;
  }

  /// The backend requires a non-empty `display_name`; the email local-part is
  /// the sensible default. Falls back to "there" for the degenerate empty case.
  String _displayNameFromEmail(String email) {
    final local = email.split('@').first.trim();
    return local.isEmpty ? 'there' : local;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.read(authServiceProvider),
    ref.read(storageServiceProvider),
    ref,
  );
});
