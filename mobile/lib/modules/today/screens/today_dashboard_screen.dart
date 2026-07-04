import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../onboarding/models/measurements_draft.dart';
import '../../profile/profile_service.dart';
import '../../profile/screens/edit_measurements_screen.dart';
import '../models/log_outfit_result.dart';
import '../models/outfit.dart';
import '../models/today_dashboard.dart';
import '../models/usage.dart';
import '../today_controller.dart';
import '../widgets/mix_match_sheet.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../widgets/outfit_card.dart';
import '../widgets/outfit_card_skeleton.dart';
import '../widgets/outfit_item_grid.dart';
import '../widgets/resume_banner.dart';
import '../widgets/usage_warning_banner.dart';
import '../widgets/weather_chip.dart';
import 'ai_reasoning_detail_screen.dart';
import 'outfit_history_screen.dart';

class TodayDashboardScreen extends ConsumerStatefulWidget {
  static const path = '/today';
  static const name = 'today_dashboard';

  const TodayDashboardScreen({super.key});

  @override
  ConsumerState<TodayDashboardScreen> createState() =>
      _TodayDashboardScreenState();
}

class _TodayDashboardScreenState extends ConsumerState<TodayDashboardScreen> {
  /// Chip row: "All" plus the occasions the backend actually generates
  /// (CTO doc 2, Screen 1). Labels map to the backend literal via
  /// [_selectedOccasion] (lowercased, spaces → underscores).
  static const _occasions = ['All', 'Work', 'Casual', 'Gym', 'Date Night'];
  int _occasionIndex = 0;

  /// Backend occasion literal for the active chip; null when "All".
  String? get _selectedOccasion => _occasionIndex == 0
      ? null
      : _occasions[_occasionIndex].toLowerCase().replaceAll(' ', '_');

  @override
  void initState() {
    super.initState();
    // Defer past the first frame so we don't mutate the provider during build.
    Future.microtask(
        () => ref.read(todayControllerProvider.notifier).loadFrame());
  }

  Future<void> _onRegenerate(String outfitId) async {
    try {
      await ref.read(todayControllerProvider.notifier).regenerate(outfitId);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429) {
        _showLimitDialog(e);
      } else {
        _showError(e.message);
      }
    }
  }

  Future<void> _onLogWorn(String outfitId) async {
    try {
      final result =
          await ref.read(todayControllerProvider.notifier).logWorn(outfitId);
      if (!mounted) return;
      _showToast(result.toast);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    }
  }

  /// Optimistic favorite toggle; the controller reverts the heart on failure.
  Future<void> _onFavorite(String outfitId) async {
    try {
      await ref.read(todayControllerProvider.notifier).toggleFavorite(outfitId);
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  /// Server-authored toast (message + colour + duration) from `POST .../log`.
  void _showToast(LogOutfitToast toast) {
    final bg = _hexColor(toast.background) ?? AppColors.espresso;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(toast.message),
          backgroundColor: bg,
          duration: Duration(milliseconds: toast.durationMs),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.espressoDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Weekly free-tier cap hit (429 `limit_reached`). The backend message already
  /// names the count + reset time; the CTA points at the (unbuilt) paywall.
  void _showLimitDialog(ApiException e) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: const Text('Weekly limit reached'),
        content: Text(e.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              debugPrint('today: upgrade tapped (limit dialog)');
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Color? _hexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: _body(state),
      ),
    );
  }

  Widget _body(TodayState state) {
    if (!state.hasData) {
      if (state.frameLoading) return const _FrameLoading();
      if (state.frameError != null) {
        return _DashboardError(
          message: state.frameError!.message,
          onRetry: () =>
              ref.read(todayControllerProvider.notifier).loadFrame(),
        );
      }
      return const SizedBox.shrink();
    }

    final dashboard = state.dashboard!;
    final pickWidgets = _pickWidgets(state, dashboard);
    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(measurementsProvider);
        return ref.read(todayControllerProvider.notifier).loadFrame();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _TopBar()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _Greeting(name: dashboard.user.name),
                const SizedBox(height: 20),
                if (dashboard.weather != null) ...[
                  _weatherChip(dashboard),
                  const SizedBox(height: 16),
                ],
                ..._usageBanner(state.usage),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _occasions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _OccasionChip(
                      label: _occasions[i],
                      selected: i == _occasionIndex,
                      onTap: () => setState(() => _occasionIndex = i),
                    ),
                  ),
                ),
                ..._resumeBanner(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.history,
                        label: 'Outfit History',
                        onTap: () => context.goNamed(OutfitHistoryScreen.name),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.auto_awesome_motion_outlined,
                        label: 'Mix & Match',
                        onTap: () {
                          if (dashboard.outfits.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Generate an outfit first to mix & match.'),
                              ),
                            );
                            return;
                          }
                          MixMatchSheet.show(context, dashboard.outfits.first);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        "Today's Picks",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Text(
                      _picksStatusLabel(state, dashboard),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.taupe,
                            letterSpacing: 1.4,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!dashboard.wardrobeReady) const _AddItemsEmptyState(),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: pickWidgets[i],
                ),
                childCount: pickWidgets.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _occasionOrder = ['work', 'casual', 'date_night', 'gym', 'other'];

  int _occasionRank(String occasion) {
    final i = _occasionOrder.indexOf(occasion);
    return i == -1 ? _occasionOrder.length : i;
  }

  String _occasionLabel(String occasion) => occasion
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// The "Today's Picks" status line — generation progress while filling,
  /// otherwise the recommended count.
  String _picksStatusLabel(TodayState state, TodayDashboard dashboard) {
    if (!dashboard.wardrobeReady) return '';
    final done = dashboard.outfits.length;
    if (state.pendingOccasions.isNotEmpty) {
      final total =
          done + state.pendingOccasions.length + state.failedOccasions.length;
      return 'STYLING $done OF $total…';
    }
    return '$done RECOMMENDED';
  }

  /// Builds the picks list: real outfit cards, then a skeleton per occasion
  /// still generating, then a retry card per occasion that failed. An active
  /// occasion chip filters all three by the backend literal; per-occasion
  /// *generation* is a follow-up (MOBILE_CHANGES P3).
  List<Widget> _pickWidgets(TodayState state, TodayDashboard dashboard) {
    final filter = _selectedOccasion;
    bool matches(String occasion) => filter == null || occasion == filter;

    final widgets = <Widget>[
      for (final outfit in dashboard.outfits)
        if (matches(outfit.occasion)) _outfitCard(state, outfit),
    ];

    final pending = state.pendingOccasions.where(matches).toList()
      ..sort((a, b) => _occasionRank(a).compareTo(_occasionRank(b)));
    for (final occasion in pending) {
      widgets.add(OutfitCardSkeleton(occasionLabel: _occasionLabel(occasion)));
    }

    final failed = state.failedOccasions.keys.where(matches).toList()
      ..sort((a, b) => _occasionRank(a).compareTo(_occasionRank(b)));
    for (final occasion in failed) {
      widgets.add(OutfitOccasionRetryCard(
        occasionLabel: _occasionLabel(occasion),
        message: state.failedOccasions[occasion]!.message,
        onRetry: () =>
            ref.read(todayControllerProvider.notifier).retryOccasion(occasion),
      ));
    }

    // The filter matched nothing today (e.g. no Gym pick was generated).
    if (widgets.isEmpty && filter != null && dashboard.wardrobeReady) {
      widgets.add(_FilteredEmptyMessage(label: _occasionLabel(filter)));
    }
    return widgets;
  }

  Widget _outfitCard(TodayState state, Outfit outfit) {
    return OutfitCard(
      outfit: OutfitCardData(
        id: outfit.id,
        occasion: outfit.occasionLabel,
        items: [
          for (final i in outfit.items)
            GarmentCell(
              imageUrl: i.primaryImageUrl,
              category: i.category,
              color: garmentColorFromName(i.colorName),
            ),
        ],
        reasoning: outfit.aiReasoningShort ?? '',
        logged: outfit.isLogged,
        favorited: outfit.isFavorite,
      ),
      regenerating: state.regeneratingIds.contains(outfit.id),
      logging: state.loggingIds.contains(outfit.id),
      onRegenerate: () => _onRegenerate(outfit.id),
      onLogWorn: () => _onLogWorn(outfit.id),
      onMix: () => MixMatchSheet.show(context, outfit),
      onFavorite: () => _onFavorite(outfit.id),
      onLearnMore: () => context.goNamed(
        AiReasoningDetailScreen.name,
        pathParameters: {'id': outfit.id},
      ),
    );
  }

  Widget _weatherChip(TodayDashboard dashboard) {
    final w = dashboard.weather!;
    return WeatherChip(
      temperature: '${w.tempC.round()}°C',
      condition: w.condition,
      hint: _weatherHint(w.tempC),
      location: dashboard.user.location,
      icon: _weatherIcon(w.condition),
    );
  }

  /// "Complete your DRAPE profile" nudge — shown while measurements are
  /// incomplete (CTO doc 2, Screen 5). Progress is computed client-side from
  /// `GET /profile/measurements` because the frame's `incomplete_profile` flag
  /// tracks onboarding, not measurements (see BE P5). Weight is optional, so
  /// all-7-required counts as complete and stops the nudge. Hidden while the
  /// fetch is loading or failed (best-effort, like the capacity banner).
  List<Widget> _resumeBanner() {
    final async = ref.watch(measurementsProvider);
    if (async is! AsyncData<MeasurementsDraft?>) return const [];
    final draft = async.value;
    if (draft != null && draft.hasAllRequired) return const [];
    return [
      const SizedBox(height: 20),
      ResumeBanner(
        stepsDone: draft?.values.length ?? 0,
        onTap: () => context.goNamed(EditMeasurementsScreen.name),
      ),
    ];
  }

  /// Weekly usage banner — only shown at 75%+ and only for free users.
  List<Widget> _usageBanner(CurrentWeekUsage? usage) {
    if (usage == null || usage.isPro) return const [];
    final c = usage.outfits;
    if (c.percentage < 75) return const [];
    final level = c.percentage >= 100
        ? UsageLevel.blocked
        : (c.percentage >= 90 ? UsageLevel.urgent : UsageLevel.soft);
    return [
      UsageWarningBanner(
        used: c.used,
        total: c.limit,
        level: level,
        onUpgrade: () => debugPrint('today: upgrade tapped'),
      ),
      const SizedBox(height: 20),
    ];
  }

  String _weatherHint(double t) {
    if (t < 5) return 'Bundle up — it’s cold out.';
    if (t < 15) return 'Cool out — layer up.';
    if (t < 24) return 'Mild — light layers work well.';
    return 'Warm — keep it light and breezy.';
  }

  IconData _weatherIcon(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('rain') || c.contains('drizzle')) return Icons.umbrella_outlined;
    if (c.contains('snow')) return Icons.ac_unit;
    if (c.contains('clear') || c.contains('sun')) return Icons.wb_sunny_outlined;
    if (c.contains('cloud')) return Icons.wb_cloudy_outlined;
    return Icons.cloud_outlined;
  }
}

/// First-paint skeleton shown only briefly while the (fast) read-only frame
/// loads and no cached dashboard is available — never a full-screen spinner.
class _FrameLoading extends StatelessWidget {
  const _FrameLoading();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _TopBar()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed(const [
              SizedBox(height: 8),
              ShimmerSkeleton(
                  width: 220,
                  height: 28,
                  borderRadius: BorderRadius.all(Radius.circular(8))),
              SizedBox(height: 12),
              ShimmerSkeleton(width: 160, height: 14),
              SizedBox(height: 24),
              OutfitCardSkeleton(),
              SizedBox(height: 24),
              OutfitCardSkeleton(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _DashboardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: AppColors.taupe, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// Shown when the wardrobe is too small to generate outfits — distinct from the
/// generating (skeleton) and error states.
class _AddItemsEmptyState extends StatelessWidget {
  const _AddItemsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.checkroom_outlined, color: AppColors.taupe, size: 44),
          const SizedBox(height: 12),
          Text(
            'Add a few wardrobe items to start getting daily outfits.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Head to the Wardrobe tab to add or scan your clothes.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.taupe),
          ),
        ],
      ),
    );
  }
}

class _FilteredEmptyMessage extends StatelessWidget {
  final String label;
  const _FilteredEmptyMessage({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.filter_alt_outlined,
              color: AppColors.taupe, size: 36),
          const SizedBox(height: 10),
          Text(
            "No $label pick in today's outfits.",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Switch to All to see everything we styled today.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.taupe),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
      child: Row(
        children: [
          Text(
            'DRAPE',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.espresso,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.espresso),
            onPressed: () => debugPrint('today: notifications'),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String name;
  const _Greeting({required this.name});

  String get _prefix {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_prefix, $name',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppColors.espressoDeep,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your daily personalized style curation is ready.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _OccasionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OccasionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.espresso : AppColors.sand,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? AppColors.white : AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.taupeSoft),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.espresso, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.espresso,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
