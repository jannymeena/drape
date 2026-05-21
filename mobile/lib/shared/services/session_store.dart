import 'package:shared_preferences/shared_preferences.dart';

/// Mock session persistence for Phase C testing. Lets a logged-in user skip
/// the welcome/onboarding flow on subsequent launches.
///
/// Phase D/E replaces this with `flutter_secure_storage` + real JWT access/
/// refresh tokens. The `isLoggedIn` flag here stands in for "has a valid
/// access token".
class SessionStore {
  SessionStore._();

  static const _kLoggedIn = 'mock_logged_in';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLoggedIn) ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLoggedIn, value);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLoggedIn);
  }
}
