import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/log_outfit_result.dart';
import '../models/today_dashboard.dart';
import '../models/usage.dart';
import '../today_controller.dart';
import '../widgets/mix_match_sheet.dart';
import '../widgets/outfit_card.dart';
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
  static const _occasions = ['Casual', 'Work', 'Gym', 'Date Night', 'Lounge'];
  int _occasionIndex = 0;

  @override
  void initState() {
    super.initState();
    // Defer past the first frame so we don't mutate the provider during build.
    Future.microtask(() => ref.read(todayControllerProvider.notifier).load());
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
      if (state.loading) return const _DashboardLoading();
      if (state.error != null) {
        return _DashboardError(
          message: state.error!.message,
          onRetry: () => ref.read(todayControllerProvider.notifier).load(),
        );
      }
      return const SizedBox.shrink();
    }

    final dashboard = state.dashboard!;
    return RefreshIndicator(
      onRefresh: () => ref.read(todayControllerProvider.notifier).load(),
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
                        onTap: () => MixMatchSheet.show(context),
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
                      '${dashboard.outfits.length} RECOMMENDED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.taupe,
                            letterSpacing: 1.4,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (dashboard.outfits.isEmpty) const _NoOutfits(),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final outfit = dashboard.outfits[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: OutfitCard(
                      outfit: OutfitCardData(
                        id: outfit.id,
                        occasion: outfit.occasionLabel,
                        itemImageUrls: outfit.gridImageUrls,
                        reasoning: outfit.aiReasoningShort ?? '',
                        logged: outfit.isLogged,
                      ),
                      regenerating: state.regeneratingIds.contains(outfit.id),
                      logging: state.loggingIds.contains(outfit.id),
                      onRegenerate: () => _onRegenerate(outfit.id),
                      onLogWorn: () => _onLogWorn(outfit.id),
                      // Mix needs the (unbuilt) Wardrobe item picker; favorite
                      // has no backend yet — both stay stubs until those land.
                      onMix: () => MixMatchSheet.show(context),
                      onFavorite: () => debugPrint('favorite ${outfit.id}'),
                      onLearnMore: () => context.goNamed(
                        AiReasoningDetailScreen.name,
                        pathParameters: {'id': outfit.id},
                      ),
                    ),
                  );
                },
                childCount: dashboard.outfits.length,
              ),
            ),
          ),
        ],
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

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.espresso),
          const SizedBox(height: 16),
          Text(
            'Curating your outfits…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
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

class _NoOutfits extends StatelessWidget {
  const _NoOutfits();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'No outfits yet — add a few wardrobe items to get started.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
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
