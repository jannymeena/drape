import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/providers/analytics_provider.dart';
import '../../../shared/providers/push_provider.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/analytics_screen_view.dart';
import '../../../shared/widgets/buy_pill.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../../onboarding/models/onboarding_status.dart';
import '../../onboarding/onboarding_service.dart';
import '../../profile/profile_service.dart';
import '../../profile/screens/compare_plans_screen.dart';
import '../../profile/screens/edit_measurements_screen.dart';
import '../../shop/screens/gap_analysis_screen.dart';
import '../../shop/shop_service.dart';
import '../../wardrobe/screens/wardrobe_screen.dart';
import '../../wardrobe/wardrobe_service.dart';
import '../day_plans_controller.dart';
import '../models/day_plan.dart';
import '../models/log_outfit_result.dart';
import '../models/outfit.dart';
import '../models/today_dashboard.dart';
import '../models/usage.dart';
import '../today_controller.dart';
import '../widgets/mix_match_sheet.dart';
import '../widgets/outfit_card.dart';
import '../widgets/outfit_card_skeleton.dart';
import '../widgets/outfit_carousel.dart';
import '../widgets/plan_day_sheet.dart';
import '../widgets/resume_banner.dart';
import '../widgets/shop_the_look_sheet.dart';
import '../widgets/starter_wardrobe_banner.dart';
import '../widgets/today_shop_section.dart';
import '../widgets/usage_meter.dart';
import '../widgets/weather_chip.dart';
import '../widgets/week_plan_strip.dart';
import 'ai_reasoning_detail_screen.dart';
import 'outfit_history_screen.dart';
import 'plan_week_screen.dart';

/// Page gutter (Stitch `px-4`).
const _gutter = 16.0;

class TodayDashboardScreen extends ConsumerStatefulWidget {
  static const path = '/today';
  static const name = 'today_dashboard';

  const TodayDashboardScreen({super.key});

  @override
  ConsumerState<TodayDashboardScreen> createState() =>
      _TodayDashboardScreenState();
}

class _TodayDashboardScreenState extends ConsumerState<TodayDashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(analyticsProvider).capture(AnalyticsEvents.todayDashboardViewed);
    // Defer past the first frame so we don't mutate the provider during build.
    Future.microtask(
        () => ref.read(todayControllerProvider.notifier).loadFrame());
    // One-time OS notification prompt, deliberately here (post-onboarding
    // home) and not at launch/login — see MOBILE_CHANGES P3. No-op after the
    // first ask, and on platforms where push is off.
    Future.microtask(() => ref.read(pushRegistrarProvider).ensurePermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the background: refresh the frame (weather) if it's gone stale.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      ref.read(todayControllerProvider.notifier).refreshIfStale();
    }
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
      // The log also wears each item, which moves the Profile stats.
      ref.invalidate(profileIntelligenceProvider);
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

  /// Server-authored toast (message + colour + duration) from `POST .../log`,
  /// rendered in the shared styled-toast shape.
  void _showToast(LogOutfitToast toast) {
    showDrapeToast(
      context,
      toast.message,
      background: _hexColor(toast.background) ?? AppColors.espresso,
      duration: Duration(milliseconds: toast.durationMs),
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

  /// Placeholder for the Today sub-screens still being built (planning,
  /// Change it, notifications, favourites).
  void _comingSoon(String what) {
    showDrapeToast(
      context,
      '$what is coming soon.',
      icon: Icons.schedule,
      background: AppColors.espressoDeep,
    );
  }

  /// Weekly free-tier cap hit (429 `limit_reached`). The backend message already
  /// names the count + reset time; the CTA points at the (unbuilt) paywall.
  void _showLimitDialog(ApiException e) {
    ref.read(analyticsProvider).capture(
      AnalyticsEvents.usageLimitReached,
      {'feature': 'outfits', 'source': 'generate'},
    );
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
              ref
                  .read(analyticsProvider)
                  .capture(AnalyticsEvents.proUpgradeTappedFromLimit);
              Navigator.of(dialogContext).pop();
              context.goNamed(ComparePlansScreen.name);
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
      if (state.frameLoading) return _FrameLoading(appBar: _appBar());
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
    final cards = _carouselCards(state, dashboard);
    final shop = _shopSection(dashboard);
    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(onboardingStatusProvider);
        return ref.read(todayControllerProvider.notifier).loadFrame();
      },
      child: CustomScrollView(
        slivers: [
          _appBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _Greeting(
                  name: dashboard.user.name,
                  weather: _weatherChip(dashboard),
                ),
                ..._contextChips(dashboard),
                ..._resumeBanner(),
                ..._starterBanner(),
                const SizedBox(height: 24),
                _OutfitsHeader(
                  status: _picksStatusLabel(state, dashboard),
                  onMyOutfits: () => context.goNamed(OutfitHistoryScreen.name),
                ),
                const SizedBox(height: 8),
                if (!dashboard.wardrobeReady) const _AddItemsEmptyState(),
              ]),
            ),
          ),
          if (dashboard.wardrobeReady)
            SliverToBoxAdapter(child: OutfitCarousel(children: cards)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                ..._usageMeter(state.usage),
                const SizedBox(height: 32),
                _weekStrip(dashboard),
                if (shop != null) ...[
                  const SizedBox(height: 32),
                  shop,
                ],
                if (dashboard.weather != null &&
                    dashboard.weatherAttribution != null) ...[
                  const SizedBox(height: 24),
                  // WeatherKit: the Apple Weather mark + data-sources link
                  // must be shown wherever its data is; Apple sets no
                  // placement, so it closes the screen that shows the pill.
                  Center(
                    child: WeatherAttributionLine(
                      attribution: dashboard.weatherAttribution!,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar() {
    return _TodayAppBar(
      onNotifications: () => _comingSoon('Notifications'),
      // Favourites isn't built yet — Outfit History holds the saved looks.
      onFavourites: () => context.goNamed(OutfitHistoryScreen.name),
    );
  }

  String _occasionLabel(String occasion) => occasion
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// Position in the backend's occasion order (unknown ones last).
  int _occasionRank(TodayDashboard dashboard, String occasion) {
    final i = dashboard.occasions.indexWhere((o) => o.key == occasion);
    return i == -1 ? dashboard.occasions.length : i;
  }

  /// The "Today's outfits" subline — generation progress while filling,
  /// otherwise the idea count.
  String _picksStatusLabel(TodayState state, TodayDashboard dashboard) {
    if (!dashboard.wardrobeReady) return 'Add a few pieces to get started';
    final done = dashboard.outfits.length;
    if (state.pendingOccasions.isNotEmpty) {
      final total =
          done + state.pendingOccasions.length + state.failedOccasions.length;
      return 'Styling $done of $total…';
    }
    return done == 1 ? '1 idea for you' : '$done ideas for you';
  }

  /// The carousel: real outfit cards, then a skeleton per occasion still
  /// generating, then a retry card per occasion that failed.
  List<Widget> _carouselCards(TodayState state, TodayDashboard dashboard) {
    final cards = <Widget>[
      for (final (i, outfit) in dashboard.outfits.indexed)
        _outfitCard(state, outfit, featured: i == 0),
    ];

    int byRank(String a, String b) =>
        _occasionRank(dashboard, a).compareTo(_occasionRank(dashboard, b));

    for (final occasion in state.pendingOccasions.toList()..sort(byRank)) {
      cards.add(OutfitCardSkeleton(occasionLabel: _occasionLabel(occasion)));
    }
    for (final occasion in state.failedOccasions.keys.toList()..sort(byRank)) {
      cards.add(OutfitOccasionRetryCard(
        occasionLabel: _occasionLabel(occasion),
        message: state.failedOccasions[occasion]!.message,
        onRetry: () => ref
            .read(todayControllerProvider.notifier)
            .generateOccasion(occasion),
      ));
    }
    return cards;
  }

  Widget _outfitCard(TodayState state, Outfit outfit, {required bool featured}) {
    return OutfitCard(
      outfit: OutfitCardData.fromOutfit(outfit),
      featured: featured,
      expand: true,
      regenerating: state.regeneratingIds.contains(outfit.id),
      logging: state.loggingIds.contains(outfit.id),
      onRegenerate: () => _onRegenerate(outfit.id),
      onLogWorn: () => _onLogWorn(outfit.id),
      onShopTheLook: () => ShopTheLookSheet.show(context, outfit),
      onMix: () => MixMatchSheet.show(context, outfit),
      onChange: () => _comingSoon('Change it'),
      onFavorite: () => _onFavorite(outfit.id),
      onLearnMore: () => context.goNamed(
        AiReasoningDetailScreen.name,
        pathParameters: {'id': outfit.id},
      ),
    );
  }

  /// Weather pill (its required source credit sits at the bottom of the
  /// screen). The "rain from 5 pm" and day-plan pills join once the backend
  /// sends forecast + plans.
  /// The weather pill, shown on the date line (right side).
  Widget? _weatherChip(TodayDashboard dashboard) {
    final w = dashboard.weather;
    if (w == null) return null;
    final condition = weatherConditionLabel(w.condition);
    return TodayContextChip(
      icon: weatherConditionIcon(w.condition),
      label: '${w.tempC.round()}°C, feels ${w.feelsLikeC.round()}°'
          '${condition == null ? '' : ' · $condition'}',
    );
  }

  /// Today's plan pill, on its own line under the date + weather.
  List<Widget> _contextChips(TodayDashboard dashboard) {
    final plan = ref.watch(dayPlansProvider)[dayOnly(DateTime.now())];
    if (plan == null) return const [];
    return [
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: TodayContextChip(
          icon: plan.occasion.icon,
          tone: TodayChipTone.plan,
          label: '${plan.note.isEmpty ? plan.occasion.label : plan.note}'
              ' · ${plan.dress.label}',
          onTap: () => _planDay(dashboard, DateTime.now()),
        ),
      ),
    ];
  }

  /// Opens Plan the day for [date]; today's sheet shows the current weather.
  void _planDay(TodayDashboard dashboard, DateTime date) {
    final w = dashboard.weather;
    final isToday = daysFromToday(date) == 0;
    final condition = w == null ? null : weatherConditionLabel(w.condition);
    PlanDaySheet.open(
      context,
      ref,
      date,
      weatherLabel: isToday && w != null
          ? '${w.tempC.round()}°C${condition == null ? '' : ' · $condition'}'
          : null,
      weatherIcon: w == null ? null : weatherConditionIcon(w.condition),
    );
  }

  /// "Complete your ZOURA profile" nudge — shown while measurements are
  /// incomplete (CTO doc 2, Screen 5). Progress comes from the backend
  /// `GET /profile/onboarding-status` payload (`measurement_steps_completed`
  /// + `next_incomplete_step`); a null next step means the 7 required are in
  /// (weight is optional) and the nudge stops. Hidden while the fetch is
  /// loading or failed (best-effort, like the capacity banner).
  List<Widget> _resumeBanner() {
    final async = ref.watch(onboardingStatusProvider);
    if (async is! AsyncData<OnboardingStatus>) return const [];
    final status = async.value;
    if (status.nextIncompleteStep == null) return const [];
    return [
      const SizedBox(height: 20),
      AnalyticsScreenView(
        event: AnalyticsEvents.resumeBannerShown,
        child: ResumeBanner(
          stepsDone: status.measurementStepsCompleted,
          onTap: () {
            ref
                .read(analyticsProvider)
                .capture(AnalyticsEvents.resumeBannerTapped);
            context.goNamed(EditMeasurementsScreen.name);
          },
        ),
      ),
    ];
  }

  /// "Unlock real wardrobe mode" card: the app is meant to run on the user's
  /// own clothes, so this stays up (not dismissible) while starter items are
  /// still in the wardrobe and the user has <10 real items — the point where
  /// outfit generation drops starter items. Same wardrobe-wide counts as the
  /// Wardrobe tab's banner; hidden while the capacity fetch is loading/failed.
  List<Widget> _starterBanner() {
    final capacity = ref.watch(wardrobeCapacityProvider).valueOrNull;
    if (capacity == null || capacity.activeStarterItems == 0) return const [];
    final real = capacity.used;
    if (real >= 10) return const [];
    return [
      const SizedBox(height: 20),
      AnalyticsScreenView(
        event: AnalyticsEvents.starterWardrobeBannerShown,
        child: StarterWardrobeBanner(
          realItems: real,
          onAdd: () {
            ref
                .read(analyticsProvider)
                .capture(AnalyticsEvents.starterWardrobeAddItemsTapped);
            context.goNamed(WardrobeScreen.name);
          },
        ),
      ),
    ];
  }

  /// Free-tier meter, always on for free users; the 75 / 90 / 100% thresholds
  /// keep firing the same analytics events the old banner did.
  List<Widget> _usageMeter(CurrentWeekUsage? usage) {
    if (usage == null || usage.isPro) return const [];
    final c = usage.outfits;
    void upgrade() {
      ref.read(analyticsProvider).capture(
        AnalyticsEvents.upgradeTapped,
        {'source': 'usage_banner'},
      );
      context.goNamed(ComparePlansScreen.name);
    }

    // Display-only for now: the meter reads "x of 10" per the redesign while
    // the backend still enforces its own weekly cap (21). The count is
    // capped at 10 so it never shows "15 of 10". Use c.limit again once the
    // backend cap changes (BACKEND_CHANGES 1.0). Analytics below stay on the
    // backend's real percentage.
    const shownLimit = 10;
    Widget meter = UsageMeter(
      used: c.used > shownLimit ? shownLimit : c.used,
      limit: shownLimit,
      onUpgrade: upgrade,
    );
    if (c.percentage >= 75) {
      final level = c.percentage >= 100
          ? 'blocked'
          : (c.percentage >= 90 ? 'urgent' : 'soft');
      meter = AnalyticsScreenView(
        // Blocked (100%) is the hard stop; below that it's a warning.
        event: level == 'blocked'
            ? AnalyticsEvents.usageLimitReached
            : AnalyticsEvents.usageLimitWarningShown,
        properties: {'feature': 'outfits', 'level': level},
        child: meter,
      );
    }
    return [meter];
  }

  /// "Your next 7 days": today is always styled (filled); other days are
  /// filled once planned (Plan the day / Plan your week).
  Widget _weekStrip(TodayDashboard dashboard) {
    final plans = ref.watch(dayPlansProvider);
    final dates = nextSevenDays();
    final days = [
      for (final (i, date) in dates.indexed)
        WeekDayCell(
          date: date,
          status: i == 0
              ? WeekDayStatus.today
              : (plans[date] == null
                  ? WeekDayStatus.open
                  : WeekDayStatus.planned),
          icon: plans[date]?.occasion.icon ?? Icons.checkroom,
        ),
    ];
    final tomorrow = dates[1];
    final plan = plans[tomorrow];
    return WeekPlanStrip(
      days: days,
      onPlanWeek: () => context.pushNamed(PlanWeekScreen.name),
      onDayTap: (date) => _planDay(dashboard, date),
      tomorrow: plan == null
          ? const TomorrowSummary(
              title: 'Tomorrow · No plan yet',
              subtitle: "Tell us what's on and we'll style it tonight",
              actionLabel: 'Plan',
              planned: false,
            )
          : TomorrowSummary(
              title: 'Tomorrow · ${plan.title} · ${plan.dress.label}',
              subtitle: 'Your outfit will be ready by 10 pm',
              actionLabel: 'Edit',
              planned: true,
            ),
      onTomorrowAction: () => _planDay(dashboard, tomorrow),
    );
  }

  /// "Shop the look": unowned pieces from today's outfits first (they are
  /// literally this look), topped up from the Shop feed; plus the biggest
  /// wardrobe gap. Both sources are best-effort — hidden while loading/failed.
  Widget? _shopSection(TodayDashboard dashboard) {
    final picks = <ShopPick>[];
    final seen = <String>{};
    for (final outfit in dashboard.outfits) {
      for (final item in outfit.items) {
        final url = item.productUrl;
        final cents = item.priceCents;
        if (url == null || cents == null || !seen.add(url)) continue;
        picks.add(ShopPick(
          name: item.name,
          imageUrl: item.primaryImageUrl,
          category: item.category,
          priceText: ShopPick.formatPrice(cents, item.currency ?? 'CAD'),
          url: url,
        ));
      }
    }
    final feed = ref.watch(shopFeedProvider).valueOrNull;
    for (final p in feed?.products ?? const []) {
      if (picks.length >= 3) break;
      if (p.productUrl.isEmpty || !seen.add(p.productUrl)) continue;
      picks.add(ShopPick(
        name: p.name,
        imageUrl: p.imageUrl,
        category: p.category,
        priceText: ShopPick.formatPrice(p.priceCents, p.currency),
        url: p.productUrl,
      ));
    }

    final topGap =
        ref.watch(gapAnalysisProvider).valueOrNull?.gaps.firstOrNull;
    final gap = topGap == null
        ? null
        : GapPick(
            title: 'Fill a gap: ${topGap.category}',
            body: topGap.outfitsUnlocked > 1
                ? '${topGap.reason} One new piece unlocks about '
                    '${topGap.outfitsUnlocked} outfits with what you own.'
                : topGap.reason,
          );

    if (picks.isEmpty && gap == null) return null;
    return TodayShopSection(
      picks: picks,
      gap: gap,
      onPickTap: (p) => openProductLink(context, p.url),
      onViewGap: () => context.goNamed(GapAnalysisScreen.name),
    );
  }

}

/// Pinned "Today" bar: serif title, notifications bell, favourites heart.
/// (Profile lives in the bottom nav.)
class _TodayAppBar extends StatelessWidget {
  final VoidCallback onNotifications;
  final VoidCallback onFavourites;
  const _TodayAppBar({
    required this.onNotifications,
    required this.onFavourites,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.ivory,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 2,
      shadowColor: const Color(0x14512F1B),
      toolbarHeight: 60,
      centerTitle: false,
      titleSpacing: 24,
      title: Text(
        'Today',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.espressoDark,
              fontWeight: FontWeight.w500,
            ),
      ),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none,
              color: AppColors.espressoDark),
          onPressed: onNotifications,
        ),
        IconButton(
          tooltip: 'Favourites',
          icon: const Icon(Icons.favorite_border,
              color: AppColors.espressoDark),
          onPressed: onFavourites,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// First-paint skeleton shown only briefly while the (fast) read-only frame
/// loads and no cached dashboard is available — never a full-screen spinner.
class _FrameLoading extends StatelessWidget {
  final Widget appBar;
  const _FrameLoading({required this.appBar});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        appBar,
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(_gutter, 8, _gutter, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              // These bars stand in for the greeting + date, so their metrics
              // mirror it — otherwise the heading visibly jumps when the frame
              // lands. Align is what makes the width stick: ShimmerSkeleton
              // sizes itself with a Container, whose width loses to the tight
              // cross-axis constraints a SliverList child is handed.
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 240,
                  child: ShimmerSkeleton(
                    height: 36,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: 90, child: ShimmerSkeleton(height: 14)),
              ),
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 200,
                  child: ShimmerSkeleton(
                    height: 28,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ),
              ),
              SizedBox(height: 24),
            ]),
          ),
        ),
        const SliverToBoxAdapter(
          child: OutfitCarousel(
            children: [OutfitCardSkeleton(), OutfitCardSkeleton()],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: todayCardShadow,
      ),
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

class _Greeting extends StatelessWidget {
  final String name;

  /// Sits at the right end of the date line; shrinks (ellipsis) before the
  /// date does.
  final Widget? weather;
  const _Greeting({required this.name, this.weather});

  String _prefix(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${weekdayShort(now)}, ${monthShort(now)} ${now.day}'.toUpperCase();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One line: a long name is cut with an ellipsis rather than
        // wrapping onto a second line.
        Text(
          '${_prefix(now)}, $name',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.greeting,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              date,
              style: text.labelMedium?.copyWith(
                color: AppColors.taupe,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
            if (weather != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: weather),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// "Today's outfits · N ideas for you" + the "My outfits" link.
class _OutfitsHeader extends StatelessWidget {
  final String status;
  final VoidCallback onMyOutfits;
  const _OutfitsHeader({required this.status, required this.onMyOutfits});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's outfits",
                style: text.headlineSmall?.copyWith(
                  color: AppColors.espressoDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(status, style: text.bodySmall),
            ],
          ),
        ),
        TextButton(
          onPressed: onMyOutfits,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.espresso,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(48, 48),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.checkroom, size: 18),
              const SizedBox(width: 6),
              Text(
                'My outfits',
                style: text.labelLarge?.copyWith(color: AppColors.espresso),
              ),
              const Icon(Icons.chevron_right, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}
