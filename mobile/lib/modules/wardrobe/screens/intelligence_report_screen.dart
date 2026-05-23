import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/wardrobe_analytics.dart';
import '../wardrobe_service.dart';

/// Wardrobe analytics hub. Composes three reports: utilization-score and
/// cost-per-wear are free (always shown); the intelligence-report is Pro — for
/// free users it 402s and the color/hidden-gems block becomes an upgrade card.
class IntelligenceReportScreen extends ConsumerWidget {
  static const path = 'intelligence';
  static const name = 'wardrobe_intelligence_report';

  const IntelligenceReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilization = ref.watch(utilizationScoreProvider);
    final costPerWear = ref.watch(costPerWearProvider);
    final intelligence = ref.watch(intelligenceReportProvider);

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  const Center(child: Text('🏆', style: TextStyle(fontSize: 28))),
                  const SizedBox(height: 4),
                  Text(
                    'Your Wardrobe\nIntelligence Report',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  const _Divider(),
                  const SizedBox(height: 18),
                  _SectionTitle('Utilization Score'),
                  const SizedBox(height: 8),
                  utilization.when(
                    loading: () => const _SectionLoader(),
                    error: (e, _) => _SectionError(error: e),
                    data: (u) => _UtilizationBlock(score: u),
                  ),
                  const SizedBox(height: 24),
                  const _Divider(),
                  const SizedBox(height: 18),
                  _SectionTitle('Cost Per Wear'),
                  const SizedBox(height: 12),
                  costPerWear.when(
                    loading: () => const _SectionLoader(),
                    error: (e, _) => _SectionError(error: e),
                    data: (r) => _CostPerWearBlock(report: r),
                  ),
                  const SizedBox(height: 24),
                  const _Divider(),
                  const SizedBox(height: 18),
                  // Pro-only block — 402 for free users.
                  intelligence.when(
                    loading: () => const _SectionLoader(),
                    error: (e, _) => (e is ApiException && e.statusCode == 402)
                        ? _ProLockCard(message: e.message)
                        : _SectionError(error: e),
                    data: (r) => _ProBlock(report: r),
                  ),
                  const SizedBox(height: 24),
                  _ShareButton(onPressed: () => debugPrint('intel: share')),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UtilizationBlock extends StatelessWidget {
  final UtilizationScore score;
  const _UtilizationBlock({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = switch (score.label.toLowerCase()) {
      'high' => AppColors.sage,
      'moderate' => AppColors.gold,
      _ => AppColors.taupe,
    };
    return Column(
      children: [
        Center(
          child: Text(
            '${score.score}/100',
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${score.label.toUpperCase()} · ${score.itemsWornRecently} of '
          '${score.itemsTotal} items worn in the last ${score.daysWindow} days',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.taupe,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _CostPerWearBlock extends StatelessWidget {
  final CostPerWearReport report;
  const _CostPerWearBlock({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.categories.isEmpty) {
      return Text(
        'Add purchase prices and log wears to see cost-per-wear.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Column(
      children: [
        for (final c in report.categories) ...[
          _CategoryCard(category: c),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CostPerWearCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final cpw = category.averageCostPerWear;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_titleCase(category.category),
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${category.itemCount} items · ${category.totalWears} wears',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.taupe,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Text(
            cpw == null ? '—' : '\$${cpw.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ProBlock extends StatelessWidget {
  final IntelligenceReport report;
  const _ProBlock({required this.report});

  @override
  Widget build(BuildContext context) {
    final slices = _paletteSlices(report.colorPalette);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('At a Glance'),
        const SizedBox(height: 12),
        _StatGrid(report: report),
        const SizedBox(height: 24),
        if (report.underutilizedItems.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond_outlined,
                  color: AppColors.espresso, size: 16),
              const SizedBox(width: 6),
              _SectionTitle('Hidden Gems'),
            ],
          ),
          const SizedBox(height: 12),
          ...report.underutilizedItems.take(4).map(
                (u) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HiddenGemRow(item: u),
                ),
              ),
          const SizedBox(height: 14),
        ],
        if (slices.isNotEmpty) ...[
          Center(child: _SectionTitle('Color Story')),
          const SizedBox(height: 12),
          Center(child: _ColorStory(palette: slices)),
          const SizedBox(height: 16),
          _PaletteLegend(palette: slices),
        ],
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  final IntelligenceReport report;
  const _StatGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final cpw = report.averageCostPerWear;
    final stats = <(String, String)>[
      ('${report.totalItems}', 'ITEMS'),
      ('${report.totalWears}', 'TOTAL WEARS'),
      (cpw == null ? '—' : '\$${cpw.toStringAsFixed(2)}', 'AVG CPW'),
      ('${(report.realVsStarterRatio * 100).round()}%', 'YOUR OWN PIECES'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final s in stats)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 40 - 12) / 2,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.taupeSoft.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.$1, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(
                    s.$2,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HiddenGemRow extends StatelessWidget {
  final IntelligenceUnderutilized item;
  const _HiddenGemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final since = item.daysSinceLastWorn;
    final subtitle = since == null
        ? 'Never worn'
        : 'Last worn $since ${since == 1 ? 'day' : 'days'} ago';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: AppColors.ivory,
              child: const Icon(Icons.checkroom_outlined,
                  color: AppColors.taupeSoft),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.titleSmall),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProLockCard extends StatelessWidget {
  final String message;
  const _ProLockCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EFFA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF4A6CB6), size: 28),
          const SizedBox(height: 10),
          Text('Atelier Intelligence',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => debugPrint('intel: upgrade (paywall not built)'),
            child: const Text('Upgrade to Pro'),
          ),
        ],
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
              'DRAPE REPORT',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.espresso,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.gold),
            onPressed: () => debugPrint('intel: share'),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.taupeSoft.withValues(alpha: 0.5));
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style:
          Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: AppColors.espresso),
          ),
        ),
      );
}

class _SectionError extends StatelessWidget {
  final Object error;
  const _SectionError({required this.error});
  @override
  Widget build(BuildContext context) {
    return Text(
      error is ApiException
          ? (error as ApiException).message
          : "Couldn't load this section.",
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

// ── color story (donut) ──────────────────────────────────────────────────

class _PaletteSlice {
  final String label;
  final double percentage;
  final Color color;
  const _PaletteSlice(this.label, this.percentage, this.color);
}

List<_PaletteSlice> _paletteSlices(List<IntelligenceColorBucket> palette) {
  final total = palette.fold<int>(0, (sum, b) => sum + b.itemCount);
  if (total == 0) return const [];
  return palette
      .map((b) => _PaletteSlice(
            b.colorName,
            b.itemCount / total,
            _colorForName(b.colorName),
          ))
      .toList();
}

Color _colorForName(String name) {
  switch (name.toLowerCase()) {
    case 'navy':
      return const Color(0xFF1B2D5A);
    case 'blue':
      return const Color(0xFF2E5BBA);
    case 'white':
      return const Color(0xFFE3DCD2);
    case 'black':
      return const Color(0xFF1B1B1B);
    case 'grey':
    case 'gray':
      return const Color(0xFF9C9A95);
    case 'brown':
    case 'camel':
      return AppColors.espresso;
    case 'green':
    case 'olive':
      return const Color(0xFF6C7833);
    case 'red':
      return const Color(0xFFB23A48);
    case 'beige':
    case 'tan':
      return AppColors.tanFixed;
    default:
      return AppColors.taupeSoft;
  }
}

class _ColorStory extends StatelessWidget {
  final List<_PaletteSlice> palette;
  const _ColorStory({required this.palette});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: _DonutPainter(palette: palette),
        child: Center(
          child: Text(
            'PALETTE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.taupe,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_PaletteSlice> palette;
  _DonutPainter({required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 28.0;
    final paintRect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    var start = -pi / 2;
    for (final slice in palette) {
      final sweep = 2 * pi * slice.percentage;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(paintRect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.palette != palette;
}

class _PaletteLegend extends StatelessWidget {
  final List<_PaletteSlice> palette;
  const _PaletteLegend({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: palette
          .map((slice) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: slice.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${slice.label.toUpperCase()} ${(slice.percentage * 100).round()}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                  ),
                ],
              ))
          .toList(),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ShareButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: Center(
            child: Text(
              'SHARE YOUR REPORT',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.espressoDark,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

String _titleCase(String s) => s
    .split(RegExp(r'[\s_]+'))
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
