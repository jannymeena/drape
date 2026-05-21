import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/mix_match_sheet.dart';
import '../widgets/outfit_card.dart';
import '../widgets/usage_warning_banner.dart';
import '../widgets/weather_chip.dart';
import 'ai_reasoning_detail_screen.dart';
import 'outfit_history_screen.dart';

class TodayDashboardScreen extends StatefulWidget {
  static const path = '/today';
  static const name = 'today_dashboard';

  const TodayDashboardScreen({super.key});

  @override
  State<TodayDashboardScreen> createState() => _TodayDashboardScreenState();
}

class _TodayDashboardScreenState extends State<TodayDashboardScreen> {
  static const _occasions = ['Casual', 'Work', 'Gym', 'Date Night', 'Lounge'];
  int _occasionIndex = 0;

  final _outfits = const <OutfitCardData>[
    OutfitCardData(
      id: 'mock-1',
      occasion: 'Work',
      itemImageUrls: [
        'https://images.unsplash.com/photo-1602810318383-e386cc2a3ccf?w=400',
        'https://images.unsplash.com/photo-1551803091-e20673f15770?w=400',
        'https://images.unsplash.com/photo-1542272604-787c3835535d?w=400',
        'https://images.unsplash.com/photo-1542838686-37da4a9fd1b3?w=400',
      ],
      reasoning:
          "The neutral palette matches today's soft morning light, while the wool layers provide comfort against the 14°C breeze.",
    ),
    OutfitCardData(
      id: 'mock-2',
      occasion: 'Casual',
      itemImageUrls: [
        'https://images.unsplash.com/photo-1604176354204-9268737828e4?w=400',
        'https://images.unsplash.com/photo-1542060748-10c28b62716f?w=400',
        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=400',
        'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=400',
      ],
      reasoning:
          'Corduroy adds a tactile element that feels sophisticated yet relaxed for a partly cloudy afternoon.',
      favorited: true,
    ),
    OutfitCardData(
      id: 'mock-3',
      occasion: 'Evening',
      itemImageUrls: [
        'https://images.unsplash.com/photo-1581655353564-df123a1eb820?w=400',
        'https://images.unsplash.com/photo-1542272604-787c3835535d?w=400',
        'https://images.unsplash.com/photo-1614252369475-531eba835eb1?w=400',
      ],
      reasoning:
          'The high-contrast dark tones transition beautifully into the cooler evening temperatures.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _TopBar()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  _Greeting(),
                  const SizedBox(height: 20),
                  const WeatherChip(
                    temperature: '14°C',
                    condition: 'Partly cloudy',
                    hint: 'Perfect for lightweight layering.',
                    location: 'New York',
                    icon: Icons.wb_cloudy_outlined,
                  ),
                  const SizedBox(height: 16),
                  UsageWarningBanner(
                    used: 16,
                    total: 21,
                    level: UsageLevel.soft,
                    onUpgrade: () => debugPrint('today: upgrade tapped'),
                  ),
                  const SizedBox(height: 20),
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
                          onTap: () =>
                              context.goNamed(OutfitHistoryScreen.name),
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
                        '${_outfits.length} RECOMMENDED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.taupe,
                              letterSpacing: 1.4,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: OutfitCard(
                      outfit: _outfits[i],
                      onRegenerate: () => debugPrint('regenerate ${_outfits[i].id}'),
                      onMix: () => MixMatchSheet.show(context),
                      onLogWorn: () => debugPrint('log worn ${_outfits[i].id}'),
                      onFavorite: () => debugPrint('favorite ${_outfits[i].id}'),
                      onLearnMore: () => context.goNamed(
                        AiReasoningDetailScreen.name,
                        pathParameters: {'id': _outfits[i].id},
                      ),
                    ),
                  ),
                  childCount: _outfits.length,
                ),
              ),
            ),
          ],
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
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good morning, Alex',
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
