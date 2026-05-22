import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps `flutter_secure_storage` for the auth tokens + cached identity.
///
/// Tokens land in the iOS Keychain / Android EncryptedSharedPreferences, so
/// they survive app restarts without sitting in plaintext prefs. The
/// lightweight "is there a session" boolean stays in [SessionStore] (shared
/// prefs) because it drives sync router gating and isn't sensitive on its own.
class StorageService {
  StorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUserId = 'user_id';
  static const _kEmail = 'user_email';

  Future<String?> getAccessToken() => _storage.read(key: _kAccess);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefresh);
  Future<String?> getUserId() => _storage.read(key: _kUserId);
  Future<String?> getEmail() => _storage.read(key: _kEmail);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
  }

  Future<void> saveIdentity({
    required String userId,
    required String email,
  }) async {
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kEmail, value: email);
  }

  Future<bool> hasSession() async => (await getAccessToken()) != null;

  Future<void> clearAll() => _storage.deleteAll();
}
