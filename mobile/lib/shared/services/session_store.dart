import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight "is there a session" flag, persisted in shared prefs.
///
/// The sensitive bits (JWT access/refresh tokens) live in [StorageService]
/// (secure storage); this boolean is only the gate the router reads. It's
/// exposed as a sync [state] `ValueNotifier` so `GoRouter`'s `redirect` (which
/// must answer synchronously) can read it and `refreshListenable` can re-run
/// the gate the moment login/logout flips it.
///
/// `AuthController.loginWithEmail` sets this to true alongside writing real
/// tokens; the mock onboarding-complete + sign-out screens still call the same
/// static API, so they keep working unchanged during the transition.
class SessionStore {
  SessionStore._();

  static const _kLoggedIn = 'mock_logged_in';

  /// Current session state, kept in sync with shared prefs. The router watches
  /// this for gating; seed it once at startup via [load].
  static final ValueNotifier<bool> state = ValueNotifier<bool>(false);

  /// Hydrates [state] from disk. Call once during app bootstrap so the router's
  /// first redirect evaluation has the right value.
  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_kLoggedIn) ?? false;
    state.value = value;
    return value;
  }

  static Future<bool> isLoggedIn() => load();

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, value);
    state.value = value;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLoggedIn);
    state.value = false;
  }
}
