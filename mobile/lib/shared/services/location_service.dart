import 'package:geolocator/geolocator.dart';

/// A device location reading, ready to pass to the dashboard for personalized
/// weather.
class DeviceCoords {
  const DeviceCoords({required this.lat, required this.lon});
  final double lat;
  final double lon;
}

/// Best-effort current location. Returns `null` (never throws) when location
/// services are off, permission is denied, or the fix times out — the backend
/// then falls back to its default coords, so the dashboard always loads.
///
/// Requests permission on first call; a permanent denial just yields `null`
/// (we don't nag with settings redirects for a weather nicety).
Future<DeviceCoords?> currentDeviceCoords() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low, // city-level is plenty for weather
        timeLimit: Duration(seconds: 8),
      ),
    );
    return DeviceCoords(lat: pos.latitude, lon: pos.longitude);
  } catch (_) {
    return null; // services unavailable / timeout / platform error
  }
}
