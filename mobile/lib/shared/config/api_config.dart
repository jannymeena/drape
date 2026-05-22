import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Resolves the backend base URL for the current platform/flavor.
///
/// Per `start_doc.md` §"Connecting a Flutter client":
/// - iOS simulator + desktop share the host network → `localhost`.
/// - Android emulator reaches the host via the `10.0.2.2` alias.
/// - A physical device needs the Mac's LAN IP (and uvicorn `--host 0.0.0.0`);
///   pass it at build time with `--dart-define=API_BASE_URL=http://<ip>:8000/api/v1`.
///
/// The `API_BASE_URL` dart-define overrides everything, which is also how the
/// tbd/prd ALB/CloudFront URL gets injected post Phase 10b.
class ApiConfig {
  ApiConfig._();

  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }
}
