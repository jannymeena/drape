import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_events.dart';
import '../analytics/analytics_service.dart';
import 'push_registrar.dart';

/// FCM-backed [PushRegistrar] (MOBILE_CHANGES P3, Android leg).
///
/// Owns the whole token lifecycle against the backend's device registry:
/// `getToken` → `POST /devices` on session start, re-register on
/// `onTokenRefresh`, `DELETE /devices/{token}` on logout. Firebase itself is
/// initialised lazily on first [register] — `main.dart` stays untouched, and
/// nothing Firebase runs for signed-out sessions.
///
/// Tap-through: a notification tap (background via `onMessageOpenedApp`,
/// cold start via `getInitialMessage`) hands the message's `data` map to
/// [onNotificationOpened]; the provider wires that to analytics + the router.
/// Foreground messages are captured as analytics only in V1 — no local
/// notification display; the in-app UI already reflects the same state.
class FcmPushRegistrar implements PushRegistrar {
  FcmPushRegistrar({
    required this._dio,
    required this._analytics,
    required this._onNotificationOpened,
  });

  static const _promptedPrefsKey = 'push_permission_prompted';

  final Dio _dio;
  final AnalyticsService _analytics;
  final void Function(Map<String, dynamic> data) _onNotificationOpened;

  String? _registeredToken;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  bool _handledInitialMessage = false;

  @override
  Future<void> register() async {
    try {
      await _ensureFirebase();
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null) return;
      await _registerToken(token);

      _refreshSub ??= messaging.onTokenRefresh.listen(
        (t) => _registerToken(t).catchError((Object e) {
          if (kDebugMode) debugPrint('push: refresh re-register failed: $e');
        }),
      );
      _openedSub ??= FirebaseMessaging.onMessageOpenedApp
          .listen((m) => _onNotificationOpened(m.data));
      _foregroundSub ??= FirebaseMessaging.onMessage.listen((m) {
        _analytics.capture(AnalyticsEvents.pushForegroundReceived, {
          'route': m.data['route'] ?? 'none',
        });
      });

      // A tap on a notification can cold-start the app; the message that did
      // is delivered once here, after the session bootstrap registers us.
      if (!_handledInitialMessage) {
        _handledInitialMessage = true;
        final initial = await messaging.getInitialMessage();
        if (initial != null) _onNotificationOpened(initial.data);
      }
    } catch (e) {
      // Best-effort by contract: a Firebase/network hiccup must never break
      // the login or bootstrap that triggered registration.
      if (kDebugMode) debugPrint('push: register failed: $e');
    }
  }

  @override
  Future<void> ensurePermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_promptedPrefsKey) ?? false) return;
      await _ensureFirebase();
      final settings = await FirebaseMessaging.instance.requestPermission();
      await prefs.setBool(_promptedPrefsKey, true);
      _analytics.capture(AnalyticsEvents.pushPermissionResult, {
        'status': settings.authorizationStatus.name,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('push: permission request failed: $e');
    }
  }

  @override
  Future<void> unregister() async {
    final token = _registeredToken;
    _registeredToken = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
    if (token == null) return;
    try {
      await _dio.delete('/devices/$token');
    } on DioException catch (e) {
      // Best-effort, like the server-side refresh-token revoke on logout.
      if (kDebugMode) debugPrint('push: unregister failed: ${e.message}');
    }
  }

  Future<void> _registerToken(String token) async {
    await _dio.post(
      '/devices',
      data: {'platform': 'android', 'token': token},
    );
    _registeredToken = token;
    if (kDebugMode) debugPrint('push: device token registered');
  }

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  }
}
