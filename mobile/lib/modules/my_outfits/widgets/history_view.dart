import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/providers/analytics_provider.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../../../shared/widgets/status_message.dart';
import '../../profile/profile_service.dart';
import '../../today/models/outfit_history.dart';
import '../../today/screens/ai_reasoning_detail_screen.dart';
import '../../today/today_service.dart';
import '../../today/widgets/outfit_card.dart';
import '../../today/widgets/outfit_collage.dart';
import '../../today/widgets/outfit_image.dart';
import '../../today/widgets/weather_chip.dart';
import '../history_months.dart';

/// The History tab of My Outfits (Stitch `my_outfits_history`): period
/// chips, the streak card, then month groups ("NOVEMBER 2026 · 3 worn ·
/// 1 skipped") of worn cards (Wear again, heart) and skipped days.
class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({super.key});

  @override
  ConsumerState<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<HistoryView> {
  HistoryFilter _filter = HistoryFilter.thisWeek;

  /// Hearts toggled here, by outfit id (the list itself isn't refetched).
  final Map<String, bool> _favourite = {};
  final Set<String> _wearing = {};

  static const _gutter = 20.0;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).capture(AnalyticsEvents.outfitHistoryViewed);
  }

  void _toast(String message, {IconData icon = Icons.schedule}) =>
      showDrapeToast(
        context,
        message,
        icon: icon,
        background: AppColors.espressoDeep,
      );

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

  /// "Wear again" logs the outfit as worn today (same endpoint as Today).
  Future<void> _wearAgain(HistoryEntry e) async {
    setState(() => _wearing.add(e.outfitId));
    try {
      final result = await ref
          .read(todayServiceProvider)
          .logOutfitWorn(e.outfitId);
      ref.invalidate(outfitHistoryProvider(_filter.query));
      ref.invalidate(profileIntelligenceProvider);
      if (!mounted) return;
      showDrapeToast(
        context,
        result.toast.message,
        background: AppColors.espresso,
        duration: Duration(milliseconds: result.toast.durationMs),
      );
    } on ApiException catch (err) {
      if (mounted) _showError(err.message);
    } finally {
      if (mounted) setState(() => _wearing.remove(e.outfitId));
    }
  }

  /// Optimistic heart; reverts on failure.
  Future<void> _toggleFavourite(HistoryEntry e) async {
    final was = _favourite[e.outfitId] ?? e.isFavorite;
    setState(() => _favourite[e.outfitId] = !was);
    try {
      final now = await ref
          .read(todayServiceProvider)
          .toggleFavorite(e.outfitId);
      if (mounted) setState(() => _favourite[e.outfitId] = now);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _favourite[e.outfitId] = was);
      _showError(err.message);
    }
  }

  void _open(HistoryEntry e) {
    ref.read(analyticsProvider).capture(AnalyticsEvents.outfitHistoryRowTapped);
    context.pushNamed(
      AiReasoningDetailScreen.name,
      pathParameters: {'id': e.outfitId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(outfitHistoryProvider(_filter.query));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(outfitHistoryProvider(_filter.query).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 40),
        children: [
          _FilterChips(
            selected: _filter,
            onSelect: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 20),
          ...switch (async) {
            AsyncData(:final value) => _content(value),
            AsyncError(:final error) => [
              StatusMessage(
                icon: Icons.cloud_off_outlined,
                title: "Couldn't load your history",
                body: error is ApiException
                    ? error.message
                    : 'Check your connection and try again.',
                action: 'Try again',
                onAction: () =>
                    ref.invalidate(outfitHistoryProvider(_filter.query)),
              ),
            ],
            _ => const [_HistorySkeleton()],
          },
        ],
      ),
    );
  }

  List<Widget> _content(OutfitHistory history) {
    final months = buildHistoryMonths(history.outfits, now: DateTime.now());
    return [
      _StreakCard(
        streak: history.currentStreak,
        onShare: () => _toast('Sharing your streak is coming soon.'),
      ),
      const SizedBox(height: 28),
      if (months.isEmpty)
        StatusMessage(
          icon: Icons.checkroom_outlined,
          title: 'Nothing logged ${_periodPhrase(_filter)}',
          body: 'Wear a look from Today and it shows up here.',
        ),
      for (final m in months) ...[
        _MonthHeader(month: m),
        const SizedBox(height: 12),
        for (final r in m.rows) ...[
          switch (r) {
            WornRow(:final entry) => _WornCard(
              entry: entry,
              favourite: _favourite[entry.outfitId] ?? entry.isFavorite,
              wearing: _wearing.contains(entry.outfitId),
              onOpen: () => _open(entry),
              onWearAgain: () => _wearAgain(entry),
              onFavourite: () => _toggleFavourite(entry),
            ),
            SkippedRow(:final day) => _SkippedCard(
              day: day,
              onAdd: () => _toast('Adding a past outfit is coming soon.'),
            ),
          },
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 18),
      ],
    ];
  }

  static String _periodPhrase(HistoryFilter f) => switch (f) {
    HistoryFilter.thisWeek => 'this week',
    HistoryFilter.thisMonth => 'this month',
    HistoryFilter.last3Months => 'in the last 3 months',
    HistoryFilter.all => 'yet',
  };
}

// ─── Period chips ───────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final HistoryFilter selected;
  final ValueChanged<HistoryFilter> onSelect;
  const _FilterChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 44,
      // Four chips: a plain scrolling row (built all at once) rather than a
      // lazy list, so the last one exists before it's scrolled to.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (final (i, f) in HistoryFilter.values.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              _chip(f, text),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(HistoryFilter f, TextTheme text) {
    final on = f == selected;
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? AppColors.espressoDark : AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: () => onSelect(f),
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Text(
                f.label,
                style: text.bodyLarge?.copyWith(
                  fontSize: 15,
                  color: on ? AppColors.white : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Streak ─────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final HistoryStreak streak;
  final VoidCallback onShare;
  const _StreakCard({required this.streak, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final days = streak.days;
    final title = days > 0 ? '$days-day streak' : 'No streak yet';
    final body = switch (days) {
      0 => "Log today's outfit to start one.",
      1 => 'You have logged an outfit today.',
      _ => 'You have logged an outfit every day for $days days.',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: todayCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.ivoryWarm,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_fire_department_outlined,
              size: 24,
              color: AppColors.espresso,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
          if (days > 0)
            TextButton(
              onPressed: onShare,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.espressoDark,
                minimumSize: const Size(48, 48),
              ),
              child: Text(
                'Share',
                style: text.bodyLarge?.copyWith(
                  color: AppColors.espressoDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Month header ───────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final HistoryMonth month;
  const _MonthHeader({required this.month});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tally = [
      '${month.worn} worn',
      if (month.skipped > 0) '${month.skipped} skipped',
    ].join(' · ');
    return Row(
      children: [
        Expanded(
          child: Text(
            month.label,
            style: text.labelMedium?.copyWith(
              color: AppColors.inkSoft,
              letterSpacing: 1.4,
              fontSize: 13,
            ),
          ),
        ),
        Text(tally, style: text.bodyMedium?.copyWith(color: AppColors.taupe)),
      ],
    );
  }
}

// ─── Cards ──────────────────────────────────────────────────────────────

const _thumbWidth = 100.0;

class _WornCard extends StatelessWidget {
  final HistoryEntry entry;
  final bool favourite;
  final bool wearing;
  final VoidCallback onOpen;
  final VoidCallback onWearAgain;
  final VoidCallback onFavourite;

  const _WornCard({
    required this.entry,
    required this.favourite,
    required this.wearing,
    required this.onOpen,
    required this.onWearAgain,
    required this.onFavourite,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final names = [for (final i in entry.items) i.name];
    final shown = names.take(2).toList();
    final more = entry.itemsCount - shown.length;
    final w = entry.weatherContext;
    final condition = w == null ? null : weatherConditionLabel(w.condition);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: todayCardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: _thumbWidth,
                  height: 130,
                  child: ColoredBox(
                    color: AppColors.ivoryWarm,
                    child: OutfitImage(
                      imageUrl: entry.imageUrl,
                      seed: entry.outfitId,
                      cells: [
                        for (final i in entry.items)
                          GarmentCell(
                            imageUrl: i.primaryImageUrl,
                            cutoutUrl: i.cutoutUrl,
                            cutoutBox: i.cutoutBox,
                            priority: i.dressPriority,
                            category: i.category,
                            color: garmentColorFromName(i.colorName),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.cardDayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w500,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.sage,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Worn',
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.sage,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Chip(entry.occasionLabel),
                        const SizedBox(width: 10),
                        Text(
                          entry.itemsCount == 1
                              ? '1 item'
                              : '${entry.itemsCount} items',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                    if (shown.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final n in shown) _Chip(n),
                          if (more > 0) _Chip('+$more'),
                        ],
                      ),
                    ],
                    // Weather on its own line: beside the buttons it doesn't
                    // fit the card's right column on a phone.
                    if (w != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            weatherConditionIcon(w.condition),
                            size: 16,
                            color: AppColors.inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${w.tempC.round()}°C'
                              '${condition == null ? '' : ' · $condition'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: _WearAgainButton(
                            loading: wearing,
                            onTap: onWearAgain,
                          ),
                        ),
                        IconButton(
                          tooltip: favourite
                              ? 'Remove from favourites'
                              : 'Add to favourites',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            favourite ? Icons.favorite : Icons.favorite_border,
                            color: AppColors.espressoDark,
                          ),
                          onPressed: onFavourite,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
      ),
    );
  }
}

class _WearAgainButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _WearAgainButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivoryWarm,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.espresso,
                    ),
                  )
                else
                  const Icon(
                    Icons.sync,
                    size: 18,
                    color: AppColors.espressoDark,
                  ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Wear again',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.espressoDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkippedCard extends StatelessWidget {
  final DateTime day;
  final VoidCallback onAdd;
  const _SkippedCard({required this.day, required this.onAdd});

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label =
        '${_weekdays[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ivoryDim,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: _thumbWidth,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.ivoryWarm,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.radio_button_unchecked,
              size: 30,
              color: AppColors.taupe,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w500,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.fast_forward_outlined,
                      size: 16,
                      color: AppColors.taupe,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Skipped',
                      style: text.bodyMedium?.copyWith(color: AppColors.taupe),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onAdd,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Add what you wore',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.espressoDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: AppColors.espressoDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading ────────────────────────────────────────────────────────────

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ShimmerSkeleton(
          height: 84,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        SizedBox(height: 28),
        ShimmerSkeleton(
          height: 160,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        SizedBox(height: 14),
        ShimmerSkeleton(
          height: 160,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ],
    );
  }
}
