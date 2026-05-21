import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/streak_pill.dart';

class OutfitHistoryScreen extends StatefulWidget {
  static const path = '/today/history';
  static const name = 'outfit_history';

  const OutfitHistoryScreen({super.key});

  @override
  State<OutfitHistoryScreen> createState() => _OutfitHistoryScreenState();
}

class _OutfitHistoryScreenState extends State<OutfitHistoryScreen> {
  static const _filters = ['This Week', 'This Month', 'Last 3 Months'];
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onBack: () => context.pop(),
              onShare: () => debugPrint('history: share'),
            ),
            _FilterChips(
              filters: _filters,
              selectedIndex: _filterIndex,
              onSelected: (i) => setState(() => _filterIndex = i),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  StreakPill(
                    days: 14,
                    onShare: () => debugPrint('history: streak share'),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(label: 'April 2026'),
                  const SizedBox(height: 8),
                  _HistoryEntry(
                    date: 'Sunday, April 12',
                    occasion: 'Brunch',
                    items: const ['Silk Blouse', 'Loafers'],
                    itemCount: 3,
                    imageUrl:
                        'https://images.unsplash.com/photo-1542060748-10c28b62716f?w=400',
                    worn: true,
                  ),
                  const SizedBox(height: 10),
                  _HistoryEntry(
                    date: 'Saturday, April 11',
                    occasion: 'Work',
                    items: const ['Wool Blazer'],
                    itemCount: 4,
                    imageUrl:
                        'https://images.unsplash.com/photo-1551803091-e20673f15770?w=400',
                    worn: true,
                  ),
                  const SizedBox(height: 10),
                  _HistoryEntry(
                    date: 'Friday, April 10',
                    occasion: 'Home',
                    items: const [],
                    itemCount: 0,
                    imageUrl: null,
                    worn: false,
                  ),
                  const SizedBox(height: 10),
                  _HistoryEntry(
                    date: 'Thursday, April 9',
                    occasion: 'Daily',
                    items: const ['Knitwear'],
                    itemCount: 2,
                    imageUrl:
                        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=400',
                    worn: true,
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(label: 'March 2026'),
                  const SizedBox(height: 8),
                  _HistoryEntry(
                    date: 'Tuesday, March 31',
                    occasion: 'Travel',
                    items: const [],
                    itemCount: 5,
                    imageUrl:
                        'https://images.unsplash.com/photo-1604176354204-9268737828e4?w=400',
                    worn: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _FilterChips({
    required this.filters,
    required this.selectedIndex,
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
          final selected = i == selectedIndex;
          return Material(
            color: selected ? AppColors.espresso : AppColors.tanFixed,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onSelected(i),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Center(
                  child: Text(
                    filters[i],
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected ? AppColors.white : AppColors.inkSoft,
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

class _HistoryEntry extends StatelessWidget {
  final String date;
  final String occasion;
  final List<String> items;
  final int itemCount;
  final String? imageUrl;
  final bool worn;

  const _HistoryEntry({
    required this.date,
    required this.occasion,
    required this.items,
    required this.itemCount,
    required this.imageUrl,
    required this.worn,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: worn ? 1 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.6)),
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
              child: Container(
                width: 80,
                height: 106,
                color: AppColors.ivoryWarm,
                child: imageUrl == null
                    ? const Center(
                        child: Icon(
                          Icons.block,
                          color: AppColors.taglineGrey,
                          size: 28,
                        ),
                      )
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.checkroom_outlined,
                          color: AppColors.taupeSoft,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          date,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      _StatusTag(worn: worn),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _OccasionPill(label: occasion, muted: !worn),
                      if (worn && itemCount > 0)
                        Text(
                          '$itemCount items',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: items
                          .map((item) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.sand,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item,
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
    );
  }
}

class _StatusTag extends StatelessWidget {
  final bool worn;
  const _StatusTag({required this.worn});

  @override
  Widget build(BuildContext context) {
    final color = worn ? AppColors.sage : AppColors.taglineGrey;
    final icon = worn ? Icons.thumb_up : Icons.fast_forward;
    final label = worn ? 'Worn' : 'Skipped';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _OccasionPill extends StatelessWidget {
  final String label;
  final bool muted;
  const _OccasionPill({required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? AppColors.sand : AppColors.tanFixed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: muted ? AppColors.inkSoft : AppColors.espressoDark,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
