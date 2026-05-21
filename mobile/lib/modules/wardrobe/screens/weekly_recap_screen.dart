import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';

class WeeklyRecapScreen extends StatelessWidget {
  static const path = 'recap';
  static const name = 'wardrobe_weekly_recap';

  const WeeklyRecapScreen({super.key});

  static const _mostWorn = <_MostWornEntry>[
    _MostWornEntry(label: 'White Oxford', wears: 4),
    _MostWornEntry(label: 'Navy Chinos', wears: 3),
    _MostWornEntry(label: 'Brown Loafers', wears: 2),
  ];

  static const _neglected = <_NeglectedEntry>[
    _NeglectedEntry(
      label: 'Gray Blazer',
      lastWorn: 'Last worn: Jan 15, 2026',
      cta: 'See How to Style This →',
    ),
    _NeglectedEntry(
      label: 'Striped Tee',
      lastWorn: 'Last worn: Dec 20, 2025',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(
                    'Your Week in Style',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Apr 14–21, 2026',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  _Card(
                    title: "THIS WEEK'S ACTIVITY",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You generated 12 outfits and wore 8 unique items.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        _WeekStrip(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    title: 'MOST-WORN ITEMS',
                    child: Row(
                      children: _mostWorn
                          .map((m) => Expanded(child: _MostWornTile(entry: m)))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    title: 'NEGLECTED ITEMS',
                    subtitle:
                        "3 items haven't been touched in 90 days",
                    child: Column(
                      children: _neglected
                          .map((entry) => _NeglectedRow(entry: entry))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _NextWeekCard(
                    onTap: () => debugPrint('recap: see next week'),
                  ),
                  const SizedBox(height: 20),
                  _ShareButton(onTap: () => debugPrint('recap: share')),
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
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Your Week in Style',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.gold),
            onPressed: () => debugPrint('recap: share'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Card({
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.taupe,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map((d) => Text(
                d,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.taupe,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
              ))
          .toList(),
    );
  }
}

class _MostWornEntry {
  final String label;
  final int wears;
  const _MostWornEntry({required this.label, required this.wears});
}

class _MostWornTile extends StatelessWidget {
  final _MostWornEntry entry;
  const _MostWornTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    color: AppColors.ivoryWarm,
                    alignment: Alignment.center,
                    child: const Icon(Icons.checkroom_outlined,
                        color: AppColors.taupeSoft, size: 32),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${entry.wears}x',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.espressoDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _NeglectedEntry {
  final String label;
  final String lastWorn;
  final String? cta;
  const _NeglectedEntry({
    required this.label,
    required this.lastWorn,
    this.cta,
  });
}

class _NeglectedRow extends StatelessWidget {
  final _NeglectedEntry entry;
  const _NeglectedRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56,
              height: 56,
              color: AppColors.ivoryWarm,
              alignment: Alignment.center,
              child: const Icon(Icons.checkroom_outlined,
                  color: AppColors.taupeSoft),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(entry.lastWorn,
                    style: Theme.of(context).textTheme.bodySmall),
                if (entry.cta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.cta!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextWeekCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NextWeekCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4A6CB6);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EFFA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.auto_awesome, color: accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            'DRAPE has pre-planned 7 outfits for your week ahead.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: accent, width: 1.4),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                child: Text(
                  'SEE NEXT WEEK',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShareButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Center(
            child: Text(
              'SHARE YOUR WEEK',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.espressoDark,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
