import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';

class IntelligenceReportScreen extends StatelessWidget {
  static const path = 'intelligence';
  static const name = 'wardrobe_intelligence_report';

  const IntelligenceReportScreen({super.key});

  static const _metrics = <_Metric>[
    _Metric(
      label: 'Tops',
      mostWorn: 'White Oxford',
      cost: r'$4.20',
      items: 14,
    ),
    _Metric(
      label: 'Bottoms',
      mostWorn: 'Navy Chinos',
      cost: r'$6.80',
      items: 8,
    ),
    _Metric(
      label: 'Shoes',
      mostWorn: 'Brown Loafers',
      cost: r'$12.10',
      items: 5,
    ),
  ];

  static const _palette = <_PaletteSlice>[
    _PaletteSlice('Navy', 0.40, Color(0xFF1B2D5A)),
    _PaletteSlice('White', 0.30, Color(0xFFE3DCD2)),
    _PaletteSlice('Brown', 0.20, AppColors.espresso),
    _PaletteSlice('Other', 0.10, AppColors.taupeSoft),
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your Wardrobe\nIntelligence Report',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'WEEK OF APR 14 – 21, 2026',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 24),
                  const _Divider(),
                  const SizedBox(height: 18),
                  _SectionTitle('Utilization Score'),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      '74/100',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: AppColors.sage,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'YOU: 34% UTILIZATION',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.taupe,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'AVG: 28%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.taupe,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You're wearing your wardrobe 21% more efficiently than the community average this week.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  const _Divider(),
                  const SizedBox(height: 18),
                  _SectionTitle('Efficiency Metrics'),
                  const SizedBox(height: 12),
                  for (final m in _metrics) ...[
                    _MetricCard(metric: m),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  const _Divider(),
                  const SizedBox(height: 18),
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
                  Row(
                    children: const [
                      Expanded(child: _HiddenGemTile(label: 'CAMEL BLAZER')),
                      SizedBox(width: 10),
                      Expanded(child: _HiddenGemTile(label: 'CASHMERE KNIT')),
                      SizedBox(width: 10),
                      Expanded(child: _HiddenGemTile(label: 'SELVEDGE DENIM')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _Divider(),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.color_lens_outlined,
                          color: AppColors.sage, size: 16),
                      const SizedBox(width: 6),
                      _SectionTitle('Variety'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      '12',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: AppColors.espresso,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'UNIQUE OUTFITS',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.taupe,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'No repeats this week! 🎉',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.sage,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _Divider(),
                  const SizedBox(height: 18),
                  _SectionTitle('Color Story'),
                  const SizedBox(height: 12),
                  _ColorStory(palette: _palette),
                  const SizedBox(height: 16),
                  _PaletteLegend(palette: _palette),
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
            icon: const Icon(Icons.menu, color: AppColors.espresso),
            onPressed: () => debugPrint('intel: menu'),
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
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.taupeSoft.withValues(alpha: 0.5),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _Metric {
  final String label;
  final String mostWorn;
  final String cost;
  final int items;

  const _Metric({
    required this.label,
    required this.mostWorn,
    required this.cost,
    required this.items,
  });
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 52,
              height: 52,
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
                Text(metric.label,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  'MOST WORN: ${metric.mostWorn.toUpperCase()}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.taupe,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(metric.cost,
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                'AVG CPW · ${metric.items} ITEMS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.taupe,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HiddenGemTile extends StatelessWidget {
  final String label;
  const _HiddenGemTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
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
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.taupe,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _PaletteSlice {
  final String label;
  final double percentage;
  final Color color;
  const _PaletteSlice(this.label, this.percentage, this.color);
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
    final strokeWidth = 28.0;
    final paintRect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

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
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.palette != palette;
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
                    decoration: BoxDecoration(
                      color: slice.color,
                      shape: BoxShape.circle,
                    ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SHARE YOUR REPORT',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.espressoDark,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward,
                    color: AppColors.espressoDark, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
