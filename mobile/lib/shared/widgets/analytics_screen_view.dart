import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/analytics_provider.dart';
import '../services/analytics/analytics_service.dart';

/// Captures one analytics event when the wrapped screen first appears.
///
/// Wrap a screen's subtree (`AnalyticsScreenView(event: ..., child: Scaffold(...))`)
/// to get a `*_viewed` event exactly once per visit — initState, not build, so
/// rebuilds never double-fire. Stateful screens with their own initState can
/// call [AnalyticsService.capture] directly instead.
class AnalyticsScreenView extends ConsumerStatefulWidget {
  const AnalyticsScreenView({
    super.key,
    required this.event,
    this.properties = const {},
    required this.child,
  });

  final String event;
  final Map<String, Object?> properties;
  final Widget child;

  @override
  ConsumerState<AnalyticsScreenView> createState() =>
      _AnalyticsScreenViewState();
}

class _AnalyticsScreenViewState extends ConsumerState<AnalyticsScreenView> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).capture(widget.event, widget.properties);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
