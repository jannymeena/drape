import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/wardrobe_analytics.dart';
import '../wardrobe_service.dart';
import 'intelligence_report_screen.dart';

/// Free weekly recap (`GET /wardrobe/analytics/weekly-report`): activity, the
/// week's most-worn items, the streak, and a Pro teaser that links to the
/// intelligence report. (Neglected-items / next-week sections from the mock
/// were dropped — they belong to the Pro intelligence report / have no
/// backend.)
class WeeklyRecapScreen extends ConsumerWidget {
  static const path = 'recap';
  static const name = 'wardrobe_weekly_recap';

  const WeeklyRecapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(weeklyReportProvider);
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: report.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
                error: (e, _) => _ErrorState(
                  message: e is ApiException
                      ? e.message
                      : "We couldn't load your recap.",
                  onRetry: () => ref.invalidate(weeklyReportProvider),
                ),
                data: (report) => _Body(report: report),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final WeeklyReport report;
  const _Body({required this.report});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'Your Week in Style',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Week of ${_dateLabel(report.weekStartDate)}',
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
                'You logged ${report.outfitsLogged} '
                '${report.outfitsLogged == 1 ? 'outfit' : 'outfits'} and wore '
                '${report.itemsWornDistinct} unique '
                '${report.itemsWornDistinct == 1 ? 'item' : 'items'}.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.local_fire_department,
                      color: AppColors.gold, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${report.streakDays}-day streak',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (report.topItems.isNotEmpty)
          _Card(
            title: 'MOST-WORN ITEMS',
            child: Row(
              children: report.topItems
                  .take(3)
                  .map((m) => Expanded(child: _MostWornTile(entry: m)))
                  .toList(),
            ),
          ),
        if (report.topItems.isNotEmpty) const SizedBox(height: 16),
        _ProTeaserCard(
          text: report.proTeaser,
          onTap: () => context.goNamed(IntelligenceReportScreen.name),
        ),
        const SizedBox(height: 20),
        _ShareButton(onTap: () => debugPrint('recap: share')),
      ],
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
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontStyle: FontStyle.italic),
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
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MostWornTile extends StatelessWidget {
  final WeeklyReportTopItem entry;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${entry.wornCount}x',
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
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ProTeaserCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _ProTeaserCard({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EFFA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF4A6CB6), size: 22),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onTap,
            child: const Text('See Intelligence Report'),
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
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dateLabel(DateTime d) {
  final local = d.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}
