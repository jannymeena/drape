import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/modules/auth/auth_controller.dart';
import 'package:mobile/modules/auth/auth_service.dart';
import 'package:mobile/modules/auth/models/auth_response.dart';
import 'package:mobile/modules/onboarding/models/measurements_draft.dart';
import 'package:mobile/modules/onboarding/onboarding_controller.dart';
import 'package:mobile/modules/today/today_controller.dart';
import 'package:mobile/modules/wardrobe/wardrobe_controller.dart';
import 'package:mobile/shared/providers/network_provider.dart';
import 'package:mobile/shared/providers/session_epoch.dart';
import 'package:mobile/shared/services/storage_service.dart';

/// Regression for the cross-account leak: register → logout → register showed
/// the previous user's data because user-scoped providers survived sign-out.
/// AuthController now bumps [sessionEpochProvider] on every session
/// transition, which rebuilds every provider that watches it.

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(Dio());

  @override
  Future<void> logout({required String refreshToken}) async {}

  @override
  Future<AuthResponse> signupWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return AuthResponse(
      userId: 'user-2',
      email: email,
      accessToken: 'access-2',
      refreshToken: 'refresh-2',
      tokenType: 'bearer',
      onboardingCompleted: false,
      nextStep: 'shopping_style',
    );
  }
}

/// In-memory stand-in for the secure-storage wrapper (no platform channels).
class _MemStorage extends StorageService {
  final _values = <String, String>{};

  @override
  Future<String?> getAccessToken() async => _values['access'];
  @override
  Future<String?> getRefreshToken() async => _values['refresh'];

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _values['access'] = accessToken;
    _values['refresh'] = refreshToken;
  }

  @override
  Future<void> saveIdentity({
    required String userId,
    required String email,
  }) async {
    _values['user_id'] = userId;
    _values['email'] = email;
  }

  @override
  Future<bool> hasSession() async => _values.containsKey('access');

  @override
  Future<void> clearAll() async => _values.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    // SessionStore + DashboardCache write to shared prefs on session changes.
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      storageServiceProvider.overrideWithValue(_MemStorage()),
    ]);
    addTearDown(container.dispose);
  });

  test('logout resets the onboarding draft (register→logout→register leak)',
      () async {
    // User A fills part of onboarding — the draft accumulates in memory.
    container.read(onboardingControllerProvider.notifier).setMeasurement(
          MeasurementField.height,
          175,
          imperial: false,
        );
    expect(
      container
          .read(onboardingControllerProvider)
          .measurements
          .get(MeasurementField.height),
      175,
    );

    await container.read(authControllerProvider.notifier).logout();

    // User B's onboarding must start from a blank draft.
    expect(
      container.read(onboardingControllerProvider).measurements.values,
      isEmpty,
    );
  });

  test('logout rebuilds the user-scoped controllers', () async {
    final todayBefore = container.read(todayControllerProvider.notifier);
    final wardrobeBefore = container.read(wardrobeControllerProvider.notifier);

    await container.read(authControllerProvider.notifier).logout();

    expect(
      identical(todayBefore, container.read(todayControllerProvider.notifier)),
      isFalse,
    );
    expect(
      identical(
        wardrobeBefore,
        container.read(wardrobeControllerProvider.notifier),
      ),
      isFalse,
    );
  });

  test('signup also bumps the epoch (defense in depth on sign-in)', () async {
    final epochBefore = container.read(sessionEpochProvider);

    await container
        .read(authControllerProvider.notifier)
        .signupWithEmail(email: 'b@example.com', password: 'password1');

    expect(container.read(sessionEpochProvider), greaterThan(epochBefore));
  });
}
