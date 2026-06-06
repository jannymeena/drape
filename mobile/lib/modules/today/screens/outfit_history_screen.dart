import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/services/share_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import '../models/outfit.dart';
import '../models/outfit_history.dart';
import '../today_service.dart';
import '../widgets/streak_pill.dart';
import 'ai_reasoning_detail_screen.dart';

/// Shares a summary of the user's logged-outfit history.
void _shareHistory(OutfitHistory? h) {
  if (h == null) {
    shareText('Tracking my outfits with DRAPE 👗', subject: 'My DRAPE history');
    return;
  }
  final parts = <String>[
    'My DRAPE outfit history:',
    if (h.currentStreak.days > 0) '• ${h.currentStreak.days}-day logging streak 🔥',
    '• ${h.totalCount} outfits logged',
  ];
  shareText(parts.join('\n'), subject: 'My DRAPE history');
}

void _shareStreak(int days) {
  shareText("🔥 I'm on a $days-day outfit-logging streak with DRAPE!",
      subject: 'My DRAPE streak');
}

/// Logged-outfit history (`GET /outfits/history`). Only worn outfits land here,
/// grouped by month, with the live streak summary up top. The filter chips map
/// to the backend `HistoryFilter` literals; switching one watches a different
/// [outfitHistoryProvider] key (and so refetches). Tapping an entry opens its
/// reasoning sheet. Share actions stay stubs (no backend).
class OutfitHistoryScreen extends ConsumerStatefulWidget {
  static const path = '/today/history';
  static const name = 'outfit_history';

  const OutfitHistoryScreen({super.key});

  @override
  ConsumerState<OutfitHistoryScreen> createState() =>
      _OutfitHistoryScreenState();
}

class _OutfitHistoryScreenState extends ConsumerState<OutfitHistoryScreen> {
  HistoryFilter _filter = HistoryFilter.thisWeek;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(outfitHistoryProvider(_filter.query));

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onBack: () => context.pop(),
              onShare: () => _shareHistory(history.valueOrNull),
            ),
            _FilterChips(
              filters: HistoryFilter.values,
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: history.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
                error: (e, _) => _ErrorState(
                  message: e is ApiException
                      ? e.message
                      : "We couldn't load your history.",
                  onRetry: () =>
                      ref.invalidate(outfitHistoryProvider(_filter.query)),
                ),
                data: (data) => data.isEmpty
                    ? const _EmptyState()
                    : _HistoryList(data: data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final OutfitHistory data;
  const _HistoryList({required this.data});

  @override
  Widget build(BuildContext context) {
    final groups = data.groupedByMonth();
    final streakDays = data.currentStreak.days;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        if (streakDays > 0) ...[
          StreakPill(
            days: streakDays,
            onShare: () => _shareStreak(streakDays),
          ),
          const SizedBox(height: 24),
        ],
        for (final entry in groups.entries) ...[
          _SectionHeader(label: entry.key),
          const SizedBox(height: 8),
          for (final item in entry.value) ...[
            _HistoryEntryCard(
              entry: item,
              onTap: () => context.pushNamed(
                AiReasoningDetailScreen.name,
                pathParameters: {'id': item.outfitId},
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onShare;
  const _Header({required this.onBack, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Outfit History',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share, color: AppColors.espresso),
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<HistoryFilter> filters;
  final HistoryFilter selected;
  final ValueChanged<HistoryFilter> onSelected;

  const _FilterChips({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final filter = filters[i];
          final isSelected = filter == selected;
          return Material(
            color: isSelected ? AppColors.espresso : AppColors.tanFixed,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onSelected(filter),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Center(
                  child: Text(
                    filter.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color:
                              isSelected ? AppColors.white : AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.taupe,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryEntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemNames =
        entry.items.map((i) => i.name).where((n) => n.isNotEmpty).toList();

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 80,
                  height: 106,
                  child: _HistoryThumbnail(items: entry.items),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.dayLabel,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const _WornTag(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _OccasionPill(label: entry.occasionLabel),
                        if (entry.itemsCount > 0)
                          Text(
                            '${entry.itemsCount} items',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                    if (itemNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: itemNames
                            .map((name) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.sand,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: AppColors.inkSoft),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
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

/// Thumbnail for a logged outfit. The backend leaves `HistoryEntry.image_url`
/// null by design (there's no composed outfit image) — the visual is built from
/// the outfit's own items, mirroring the Today tab's 2×2 grid. We surface the
/// first item that has a photo; failing that, a coloured category silhouette of
/// the first item (the app's house placeholder), and only an empty-state hanger
/// when the outfit carries no items at all.
class _HistoryThumbnail extends StatelessWidget {
  final List<OutfitItem> items;

  const _HistoryThumbnail({required this.items});

  Widget _placeholderFor(OutfitItem item) => GarmentPlaceholder(
        category: item.category,
        color: garmentColorFromName(item.colorName),
      );

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const ColoredBox(
        color: AppColors.ivoryWarm,
        child: Center(
          child: Icon(
            Icons.checkroom_outlined,
            color: AppColors.taupeSoft,
            size: 28,
          ),
        ),
      );
    }

    final photoItem = items.firstWhere(
      (i) => i.primaryImageUrl != null && i.primaryImageUrl!.isNotEmpty,
      orElse: () => items.first,
    );
    final url = photoItem.primaryImageUrl;
    if (url == null || url.isEmpty) {
      return _placeholderFor(photoItem);
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholderFor(photoItem),
    );
  }
}

class _WornTag extends StatelessWidget {
  const _WornTag();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.thumb_up, color: AppColors.sage, size: 14),
        const SizedBox(width: 4),
        Text(
          'Worn',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.sage,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _OccasionPill extends StatelessWidget {
  final String label;
  const _OccasionPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tanFixed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.espressoDark,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.checkroom_outlined,
                color: AppColors.taupeSoft, size: 48),
            const SizedBox(height: 16),
            Text(
              'No outfits logged yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Log an outfit as worn from Today and it will show up here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
