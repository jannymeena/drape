import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/outline_chip.dart';
import 'pre_measurement_screen.dart';

class LifestyleOccasionsScreen extends StatefulWidget {
  static const path = '/onboarding/lifestyle';
  static const name = 'lifestyle';

  const LifestyleOccasionsScreen({super.key});

  @override
  State<LifestyleOccasionsScreen> createState() =>
      _LifestyleOccasionsScreenState();
}

class _LifestyleOccasionsScreenState extends State<LifestyleOccasionsScreen> {
  final _selected = <String>{'Office', 'Evenings out', 'Weekend casual'};
  double _formality = 0.6;

  static const _occasions = [
    'Office', 'Working from home',
    'Casual errands', 'Gym & fitness',
    'Evenings out', 'Date nights', 'Formal events',
    'Travel', 'Outdoor activities',
    'Weekend casual', 'School/College',
    'Creative work',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DrapeAppBar(
        showBack: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.tanFixed,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              'STEP 3 OF 3 — STYLE PROFILE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.espressoDark,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              'How Do You Live?',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Where do you spend most of your time? This shapes your daily outfit suggestions.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _SectionLabel(label: 'WHERE I DRESS FOR'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in _occasions)
                  OutlineChip(
                    label: o,
                    selected: _selected.contains(o),
                    onPressed: () => setState(() {
                      if (!_selected.add(o)) _selected.remove(o);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            _SectionLabel(label: 'MY TYPICAL WEEK IS'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Relaxed',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text('Dressed up',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: AppColors.espresso,
                inactiveTrackColor: AppColors.tanFixed,
                thumbColor: AppColors.espresso,
                overlayColor: AppColors.espresso.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: _formality,
                onChanged: (v) => setState(() => _formality = v),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: AppColors.ivoryWarm,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.dry_cleaning,
                        color: AppColors.taupe, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '"Style is a way to say who you are without having to speak."',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.inkSoft,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            DrapeButton(
              label: 'See My First Outfit',
              onPressed: () => context.pushNamed(PreMeasurementScreen.name),
              leading: const Icon(Icons.arrow_forward,
                  color: AppColors.white, size: 18),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'You can update these anytime in your profile.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.inkSoft,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
