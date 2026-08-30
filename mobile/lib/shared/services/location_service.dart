import 'package:geolocator/geolocator.dart';

/// A device location reading, ready to pass to the dashboard for personalized
/// weather.
class DeviceCoords {
  const DeviceCoords({required this.lat, required this.lon});
  final double lat;
  final double lon;
}

/// How long the whole lookup — service check, permission prompt and fix — may
/// take before we give up and let the caller proceed without coordinates.
///
/// This is deliberately short. Coordinates only personalize the weather line;
/// the backend falls back to default coords without them. Anything the user is
/// waiting on must not be gated behind a location fix.
const Duration _kLocationBudget = Duration(seconds: 3);

/// Best-effort current location. Returns `null` (never throws, never hangs)
/// when location services are off, permission is denied or unanswered, or no
/// fix arrives within [timeout] — the backend then falls back to its default
/// coords, so the dashboard always loads.
///
/// The overall timeout is the important part. `getCurrentPosition`'s own
/// `timeLimit` only bounds the fix itself, and `requestPermission()` is
/// unbounded: if its dialog never gets answered — which happens when another
/// permission dialog (push, on first launch) takes the screen first — that
/// future never completes, and anything awaiting it waits forever.
///
/// Requests permission on first call; a permanent denial just yields `null`
/// (we don't nag with settings redirects for a weather nicety).
Future<DeviceCoords?> currentDeviceCoords({
  Duration timeout = _kLocationBudget,
}) async {
  try {
    return await _lookup(timeout).timeout(timeout);
  } catch (_) {
    // Services unavailable, permission unanswered, no fix, platform error —
    // all the same to the caller.
    return null;
  }
}

Future<DeviceCoords?> _lookup(Duration budget) async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  // Fast path: a cached fix is good enough for a weather lookup and costs
  // nothing, where a fresh fix can take seconds (or never arrive at all on a
  // device or emulator with no location source).
  final last = await Geolocator.getLastKnownPosition();
  if (last != null) {
    return DeviceCoords(lat: last.latitude, lon: last.longitude);
  }

  final pos = await Geolocator.getCurrentPosition(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.low, // city-level is plenty for weather
      timeLimit: budget,
    ),
  );
  return DeviceCoords(lat: pos.latitude, lon: pos.longitude);
}
