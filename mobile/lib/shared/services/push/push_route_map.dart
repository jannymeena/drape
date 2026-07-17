import '../../../modules/profile/screens/compare_plans_screen.dart';

/// Maps the backend's notification `data.route` literals (see the
/// `push_service.notify_user` call sites in `today.py` / `outfits.py`) to
/// router route names for tap-through navigation.
///
/// Unknown or missing routes resolve to null and the tap lands on whatever
/// screen the app opens to — a notification must never crash navigation.
/// Grow this map alongside new backend `data.route` literals.
const Map<String, String> _pushRouteNames = {
  'paywall': ComparePlansScreen.name,
};

String? pushRouteNameFor(Object? route) {
  if (route is! String) return null;
  return _pushRouteNames[route];
}
