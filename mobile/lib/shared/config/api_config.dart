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

  /// Dev hosts the backend may bake into image URLs that aren't reachable as-is
  /// from every device (e.g. `localhost` from the Android emulator).
  static const _devBackendHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

  /// Rewrites a backend-served image URL so its host matches the host the app
  /// uses for the API. In dev the backend hardcodes `localhost:8000` into image
  /// URLs, which a device/emulator can't reach — but the API host *is* reachable
  /// (that's how the JSON arrived), so we swap it in. External URLs (e.g. a CDN)
  /// are left untouched.
  static String? resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme) return url;
    if (!_devBackendHosts.contains(parsed.host)) return url;
    final api = Uri.parse(baseUrl);
    return parsed
        .replace(scheme: api.scheme, host: api.host, port: api.port)
        .toString();
  }
}
